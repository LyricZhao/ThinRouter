"""
生成以太网帧的测试用例

输出会存储到 ../io_manager_test.mem

每行，
如果以 "info:      " 开头，则为注释，应打印整行
如果以 "eth_frame: " 开头，则为 hex 表示的数据包，以 FFF 结束
如果以 "expect:    " 开头，则为 hex 表示的应当返回的数据包，以 FFF 结束
如果以 "discard"     开头，则表示前面一个数据包应当被丢弃

todo:
连上 IP 表、ARP 表后有对应的测例

ARP 包:
-8  0x55555555555555D5  Preamble
0   目标 MAC
6   来源 MAC
12  0x8100  VLAN
14  最低两位为 VLAN ID
16  0x0806  ARP
18  0x0001  以太网
20  0x0800  IPv4
22  0x06    硬件地址长度
23  0x04    协议地址长度
24  0x0001  ARP Request
26  来源 MAC
32  来源 IP
36  目标 MAC (全 0)
42  目标 IP
46  CRC
50

IP 包:
-8  0x55555555555555D5  Preamble
0   目标 MAC
6   来源 MAC
12  0x8100  VLAN
14  最低两位为 VLAN ID
16  0x0800  IPv4
18  0x45    Protocol v4, header 大小 20B
19  0x00    DSF
20  IP 包长度
22  连续包识别码
24  [174]=DF, [173]=MF, [172:160]=Offset （用于分包）
26  TTL
27  IP 协议
28  Checksum
30  来源 IP
34  目标 IP
38  数据
??  CRC
??

其他包:
-8  0x55555555555555D5  Preamble
0   目标 MAC
6   来源 MAC
12  0x8100  VLAN
14  最低两位为 VLAN ID
16  ????
??  CRC
??

不完整包:
任何包在意料不到的位置中断
"""
from __future__ import annotations
from typing import *
import random
import sys
import random
import os
import struct
import zlib
import json
import re


def chance(c: float) -> bool:
    return random.random() < c


def big_hex(v: int, size: int) -> str:
    s = ''
    for i in range(size):
        s = '%02X ' % (v & 0xff) + s
        v >>= 8
    return s


def little_hex(v: int, size: int) -> str:
    s = ''
    for i in range(size):
        s += '%02X ' % (v & 0xff)
        v >>= 8
    return s


class Config:
    count = 128             # 生成多少测例
    discard_rate = 0.5      # 错误测例的比例
    max_data_length = 556   # IP 包数据段最大长度
    path = ''               # (maybe) relative path to runtime_path directory


def wrong_usage_exit():
    print('\033[31mInvalid arguments\033[0m')
    print(
        'Arguments:',
        '-c <count>',
        '\tSpecify how many testcases to generate. Default is %d.' % Config.count,
        '-d <discard_rate>',
        '\tSpecify the ratio of testcases that should be discarded. Default is %.2f.' % Config.discard_rate,
        '-l <max_data_length>',
        '\tSpecify the max length of IP packet data. Default is %d.' % Config.max_data_length
    )
    exit(0)


class MAC:
    @staticmethod
    def get_broadcast() -> MAC:
        return MAC('ff:ff:ff:ff:ff:ff')

    @staticmethod
    def get_none() -> MAC:
        return MAC(0)

    @staticmethod
    def get_random() -> MAC:
        return MAC(random.randrange(16 ** 12))

    def __init__(self, value: Union[str, int]):
        if type(value) is str:
            self.value = int(re.sub(':', '', value), base=16)
        elif type(value) is int:
            self.value = value
        else:
            raise TypeError()

    @property
    def hex(self) -> str:
        """
        生成保存在测例文件中的 hex 串
        """
        return big_hex(self.value, 6)

    @property
    def raw(self) -> bytearray:
        """
        生成实际的 bytearray
        """
        return struct.pack('>q', self.value)[2:]

    def __str__(self) -> str:
        """
        生成打印格式的字符串
        """
        if self.value == 0xff_ff_ff_ff_ff_ff:
            return 'Broadcast'
        else:
            return '%s%s:%s%s:%s%s:%s%s:%s%s:%s%s' % tuple('%012x' % self.value)

    def __hash__(self):
        return self.value

    def __eq__(self, other):
        return self.value == other.value


class IP:
    @staticmethod
    def get_random(router: IP, mask: int) -> IP:
        """
        返回路由器子网内但不同于路由器的 IP 地址
        """
        addr = router.value
        while addr == router.value:
            addr &= 0xffffffff << (32 - mask)
            # addr += random.randrange(16 ** 8) & (0xffffffff >> mask)
            addr += 123 & (0xffffffff >> mask)
        return IP(addr)

    def __init__(self, value: Union[str, int]):
        if type(value) is str:
            self.value = int(''.join('%02x' % int(v)
                                     for v in value.split('.')), base=16)
        elif type(value) is int:
            self.value = value
        else:
            raise TypeError()

    @property
    def hex(self) -> str:
        """
        生成保存在测例文件中的 hex 串
        """
        return big_hex(self.value, 4)

    def __str__(self):
        """
        生成打印格式的字符串
        """
        return '%d.%d.%d.%d' % (self.value >> 24, (self.value >> 16) & 255, (self.value >> 8) & 255, self.value & 255)

    @property
    def raw(self) -> bytearray:
        """
        生成实际的 bytearray
        """
        return struct.pack('>I', self.value)

    def __hash__(self):
        return self.value

    def __eq__(self, other):
        return self.value == other.value


class ArpRequest:
    def __init__(self, dst_ip: IP, src_mac: MAC, src_ip: IP):
        self.dst_mac = MAC.get_none()
        self.dst_ip = dst_ip
        self.src_mac = src_mac
        self.src_ip = src_ip

    @property
    def hex(self) -> str:
        return (
            '08 06 00 01 08 00 06 04 00 01 ' +
            self.src_mac.hex + self.src_ip.hex +
            self.dst_mac.hex + self.dst_ip.hex
        )

    @property
    def raw(self) -> bytearray:
        return (
            b'\x08\x06\x00\x01\x08\x00\x06\x04\x00\x01' +
            self.src_mac.raw + self.src_ip.raw +
            self.dst_mac.raw + self.dst_ip.raw
        )

    def __str__(self):
        return 'ARP Request: %s(%s) -> %s' % (self.src_ip, self.src_mac, self.dst_ip)


class IpRequest:
    dst_ip: IP
    src_ip: IP
    id: int
    ttl: int
    ip_protocol: int
    data: List[int]
    ip_len: int
    checksum: int

    def __init__(self, dst_ip: IP, src_ip: IP):
        self.dst_ip = dst_ip
        self.src_ip = src_ip
        self.id = random.randrange(16**4)
        self.ttl = random.choice([64, 128, 255])
        self.ip_protocol = random.randrange(256)
        if chance(0.3):
            self.ip_len = 20
            self.data = []
        else:
            data_len = random.randrange(Config.max_data_length + 1)
            self.data = [random.randrange(256) for i in range(data_len)]
            self.ip_len = data_len + 20
        checksum = (
            0x4500 +
            self.ip_len +
            self.id +
            (self.ttl << 8) + self.ip_protocol +
            (self.src_ip.value >> 16) + (self.src_ip.value & 0xffff) +
            (self.dst_ip.value >> 16) + (self.dst_ip.value & 0xffff)
        )
        if checksum > 0xffff:
            checksum = (checksum >> 16) + (checksum & 0xffff)
        if checksum > 0xffff:
            checksum = (checksum >> 16) + (checksum & 0xffff)
        self.checksum = checksum ^ 0xffff

    @property
    def hex(self) -> str:
        return (
            '08 00 45 00 ' +
            big_hex(self.ip_len, 2) +
            big_hex(self.id, 2) +
            '00 00 %02X %02X ' % (self.ttl, self.ip_protocol) +
            big_hex(self.checksum, 2) +
            self.src_ip.hex +
            self.dst_ip.hex +
            ''.join('%02X ' % c for c in self.data)
        )

    @property
    def raw(self) -> bytearray:
        return (
            b'\x08\x00\x45\x00' +
            self.ip_len.to_bytes(2, 'big') +
            self.id.to_bytes(2, 'big') +
            b'\x00\x00' +
            self.ttl.to_bytes(1, 'big') +
            self.ip_protocol.to_bytes(1, 'big') +
            self.checksum.to_bytes(2, 'big') +
            self.src_ip.raw +
            self.dst_ip.raw +
            b''.join(c.to_bytes(1, 'big') for c in self.data)
        )

    def __str__(self):
        return 'IP Request: %s -> %s' % (self.src_ip, self.dst_ip)


class EthFrame:
    """
    以太网帧，需要生成 Preamble, dest MAC, src MAC, VLAN TAG, CRC
    """
    # 四个子网，子网内第一条为路由器，会在 ARP 时添加新的记录
    subnets: List[List[Tuple[MAC, IP]]] = [
        [],
        [(MAC('a8:88:08:18:88:88'), IP('10.4.1.1'))],
        [(MAC('a8:88:08:28:88:88'), IP('10.4.2.1'))],
        [(MAC('a8:88:08:38:88:88'), IP('10.4.3.1'))],
        [(MAC('a8:88:08:48:88:88'), IP('10.4.4.1'))],
    ]

    @staticmethod
    def get_preamble():
        return '55 ' * random.randint(4, 16) + 'D5 '

    @staticmethod
    def get_arp() -> EthFrame:
        port = random.randint(1, 4)
        # 广播，问路由器
        dst_mac = MAC.get_broadcast()
        dst_ip = EthFrame.subnets[port][0][1]
        # 来源是子网内某个 IP MAC
        src_ip = IP.get_random(router=dst_ip, mask=24)
        for mac, ip in EthFrame.subnets[port]:
            if ip == src_ip:
                src_mac = mac
        else:
            src_mac = MAC.get_random()
            EthFrame.subnets[port].append((src_mac, src_ip,))

        request = ArpRequest(dst_ip, src_mac, src_ip)
        return EthFrame(dst_mac, src_mac, port, request)

    @staticmethod
    def get_ip() -> Optional[EthFrame]:
        port, dst_port = random.sample(range(1, 5), 2)
        # 要求发出和接收的子网内都有路由器以外的机器
        if len(EthFrame.subnets[port]) == 1 or len(EthFrame.subnets[dst_port]) == 1:
            return None
        src_mac, src_ip = random.choice(EthFrame.subnets[port][1:])
        dst_ip = random.choice(EthFrame.subnets[dst_port][1:])[1]
        # 发给路由器
        dst_mac = EthFrame.subnets[port][0][0]
        request = IpRequest(dst_ip, src_ip)
        return EthFrame(dst_mac, src_mac, port, request)

    def __init__(self, dst_mac: MAC, src_mac: MAC, port: int, ip_layer_data: Union[ArpRequest, IpRequest]):
        """
        使用已有的信息包装成一个以太网帧
        """
        self.dst_mac = dst_mac
        self.src_mac = src_mac
        self.port = port
        self.ip_layer_data = ip_layer_data
        data_len = len(ip_layer_data.raw)
        if data_len >= 44:
            self.padding_size = 0
        else:
            self.padding_size = 44 - data_len
        raw = (
            dst_mac.raw +
            src_mac.raw +
            b'\x81\x00' + struct.pack('>H', self.port) +
            ip_layer_data.raw +
            b'\x00' * self.padding_size
        )
        self.crc = little_hex(zlib.crc32(raw), 4)

    @property
    def hex(self) -> str:
        return (
            # EthFrame.get_preamble() +
            self.dst_mac.hex +
            self.src_mac.hex +
            '81 00 00 0%d ' % self.port +
            self.ip_layer_data.hex +
            '00 ' * self.padding_size +
            self.crc
        )

    def __str__(self):
        return '%s -> %s: %s' % (self.src_mac, self.dst_mac, self.ip_layer_data)


def parse_arguments() -> bool:
    state = ''
    try:
        # get path
        scripts_path = os.path.dirname(sys.argv[0])
        Config.path = os.path.normpath(os.path.join(scripts_path, '..'))
        # parse arguments
        for v in sys.argv[1:]:
            if state == '':
                if v == '-c':
                    state = 'c'
                elif v == '-d':
                    state = 'd'
                elif v == '-l':
                    state = 'l'
                else:
                    return False
            elif state == 'c':
                Config.count = int(v)
                if Config.count < 0:
                    return False
                state = ''
            elif state == 'd':
                Config.discard_rate = float(v)
                if not 0 <= Config.discard_rate <= 1:
                    return False
                state = ''
            elif state == 'l':
                Config.max_data_length = int(v)
                if Config.max_data_length < 0:
                    return False
                state = ''
        return state == ''
    except (ValueError):
        return False


if __name__ == '__main__':
    # MAC.test()
    # IP.test()
    if not parse_arguments():
        wrong_usage_exit()

    output = ''
    for i in range(Config.count):
        frame = None
        while frame is None:
            if chance(0.3):
                frame = EthFrame.get_arp()
            else:
                frame = EthFrame.get_ip()
        output += 'info:      %s\neth_frame: %sFFF\n' % (frame, frame.hex)

    print('已生成 %d 条测试样例' %
          (Config.count))

    open(os.path.join(Config.path, 'io_manager_test.mem'), 'w').write(output)
