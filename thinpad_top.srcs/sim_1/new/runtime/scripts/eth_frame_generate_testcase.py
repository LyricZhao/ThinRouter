"""
生成以太网帧的测试用例

输出会存储到 ../eth_frame_test.mem

每行，
如果以 "info:      " 开头，则为注释，应打印整行
如果以 "eth_frame: " 开头，则为 hex 表示的数据包
如果以 "expect:    " 开头，则为 hex 表示的应当返回的数据包
如果以 "discard"     开头，则表示前面一个数据包应当被丢弃

todo: 
连上 IP 表、ARP 表后有对应的测例

目前涉及的 MAC 都还只从以下值抽取:
    ROUTER: a8:88:08:88:88:88   @0  10.0.4.1
    TYX:    00:e0:4c:68:06:e2   @0  10.0.4.2
    ZCG:    00:0e:c6:cb:3d:c0   @1  10.0.4.3
    WZY:    a4:4c:c8:0e:e0:95   @2  10.0.4.4
    EXT:    9c:eb:e8:b4:e7:e4   @3  10.0.4.5

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
30  目标 IP
34  来源 IP
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

CRC 有误包:
CRC 有问题
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
        s += ' %02X' % (v & 0xff)
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


# MAC & VLAN ID
class MAC:
    used: Set[MAC] = set()  # 使用过的 MAC 地址

    @staticmethod
    def test():
        mac = MAC.get_random()
        print(mac)
        print(mac.raw)
        print(mac.hex)

    @staticmethod
    def get_broadcast():
        return MAC(0xff_ff_ff_ff_ff_ff, 0)

    @staticmethod
    def get_none():
        return MAC(0, 0)

    @staticmethod
    def get_random():
        # return MAC(random.randrange(16 ** 12), random.randrange(4))
        return MAC(*random.choice([
            (0xa8_88_08_88_88_88, 0),
            (0x00_e0_4c_68_06_e2, 0),
            (0x00_0e_c6_cb_3d_c0, 1),
            (0xa4_4c_c8_0e_e0_95, 2),
            (0x9c_eb_e8_b4_e7_e4, 3)
        ]))

    @staticmethod
    def get_used():
        """
        生成一个用过的 MAC 地址
        """
        if len(MAC.used) == 0:
            return MAC.get_random()
        else:
            return random.choice(list(MAC.used))

    @staticmethod
    def get_unused():
        """
        生成一个没有用过的 MAC 地址
        """
        mac = MAC(random.randrange(16 ** 12), random.randrange(4))
        while mac in MAC.used:
            mac = MAC(random.randrange(16 ** 12), random.randrange(4))
        return mac

    def __init__(self, value, vlan_id):
        self.value = value
        self.vlan_id = vlan_id

    @property
    def hex(self) -> str:
        """
        生成保存在测例文件中的 hex 串
        """
        return '%s%s %s%s %s%s %s%s %s%s %s%s ' % tuple('%012X' % self.value)

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
    used: Set[IP] = set()   # 使用过的 IP 地址

    @staticmethod
    def test():
        ip = IP.get_random()
        print(ip)
        print(ip.raw)
        print(ip.hex)

    @staticmethod
    def get_random():
        # return IP(random.randrange(16 ** 8))
        return IP(random.choice([
            0x0a000401, 0x0a000402, 0x0a000403, 0x0a000404, 0x0a000405
        ]))

    @staticmethod
    def get_used():
        """
        生成一个用过的 IP 地址
        """
        if len(IP.used) == 0:
            return IP.get_random()
        else:
            return random.choice(list(IP.used))

    @staticmethod
    def get_unused():
        """
        生成一个没有用过的 IP 地址
        """
        ip = IP(random.randrange(16 ** 8))
        while ip in IP.used:
            ip = IP(random.randrange(16 ** 12))
        return ip

    def __init__(self, value):
        self.value = value

    @property
    def hex(self):
        """
        生成保存在测例文件中的 hex 串
        """
        return '%s%s %s%s %s%s %s%s ' % tuple('%08X' % self.value)

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
    def __init__(self, dst_ip, src_mac, src_ip):
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
    def __init__(self, dst_ip, src_ip):
        self.dst_ip = dst_ip
        self.src_ip = src_ip
        self.id = random.randrange(16**4)
        self.ttl = random.choice([64, 128, 255])
        self.ip_protocol = random.randrange(256)
        if chance(0.3):
            self.ip_len = 20
            self.data = []
        else:
            data_len = random.randint(24, 512)
            self.data = [random.randrange(256) for i in range(data_len)]
            self.ip_len = data_len + 20
        checksum = (
            0x4500 +
            self.ip_len +
            self.id +
            (self.ttl << 8) + self.ip_protocol +
            (self.dst_ip.value >> 16) + (self.dst_ip.value & 0xffff) +
            (self.src_ip.value >> 16) + (self.src_ip.value & 0xffff)
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
            self.dst_ip.hex +
            self.src_ip.hex +
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
    preamble = '55 55 55 55 55 55 55 D5 '

    @staticmethod
    def get_arp():
        """
        以太网帧，需要生成 Preamble, dest MAC, src MAC, VLAN TAG, CRC
        """
        if random.random() < 0.3:
            dst_mac = MAC.get_used()
        else:
            dst_mac = MAC.get_broadcast()
        dst_ip = IP.get_random()
        src_mac = MAC.get_random()
        src_ip = IP.get_random()
        request = ArpRequest(dst_ip, src_mac, src_ip)
        return EthFrame(dst_mac, src_mac, request)

    @staticmethod
    def get_ip():
        if random.random() < 0.3:
            dst_mac = MAC.get_unused()
        else:
            dst_mac = MAC.get_used()
        src_mac = MAC.get_random()
        dst_ip = IP.get_random()
        src_ip = IP.get_random()
        request = IpRequest(dst_ip, src_ip)
        return EthFrame(dst_mac, src_mac, request)

    def __init__(self, dst_mac: MAC, src_mac: MAC, ip_layer_data):
        """
        使用已有的信息包装成一个以太网帧
        """
        self.dst_mac = dst_mac
        self.src_mac = src_mac
        self.ip_layer_data = ip_layer_data
        raw = (
            dst_mac.raw +
            src_mac.raw +
            b'\x81\x00' + struct.pack('>H', src_mac.vlan_id) +
            ip_layer_data.raw
        )
        crc = '%08X' % zlib.crc32(raw)
        self.crc = ' '.join([crc[6:], crc[4:6], crc[2:4], crc[:2]])

    @property
    def hex(self) -> str:
        return (
            EthFrame.preamble +
            self.dst_mac.hex +
            self.src_mac.hex +
            '81 00 00 0%d ' % self.src_mac.vlan_id +
            self.ip_layer_data.hex +
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

    frame = EthFrame.get_ip()
    print(frame)
    print(frame.hex)

    output = ''
    for i in range(Config.count):
        if chance(0.3):
            frame = EthFrame.get_arp()
        else:
            frame = EthFrame.get_ip()
        output += 'info:      %s\neth_frame: %s\n' % (frame, frame.hex)

    print('已生成 %d 条测试样例' %
          (Config.count))

    open(os.path.join(Config.path, 'eth_frame_test.mem'), 'w').write(output)
