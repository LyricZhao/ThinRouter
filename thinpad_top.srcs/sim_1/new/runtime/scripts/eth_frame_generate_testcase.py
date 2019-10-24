"""
生成以太网帧的测试用例

输出会存储到 ../eth_frame_test.mem

每行，
如果以 "info:      " 开头，则为注释，应打印整行
如果以 "eth frame: " 开头，则为 hex 表示的数据包
如果以 "expect:    " 开头，则为 hex 表示的应当返回的数据包
如果以 "discard"     开头，则表示前面一个数据包应当被丢弃

todo: 
连上 IP 表、ARP 表后有对应的测例

目前涉及的 MAC 都还只从以下值抽取:
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
20  0x8000  IPv4
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
import binascii
import json


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
    def get_random():
        # return MAC(random.randrange(16 ** 12), random.randrange(4))
        return MAC(*random.choice([
            (0x00e04c6806e2, 0),
            (0x000ec6cb3dc0, 1),
            (0xa44cc80ee095, 2),
            (0x9cebe8b4e7e4, 3)
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
    def hex(self):
        """
        生成保存在测例文件中的 hex 串
        """
        return '%s%s %s%s %s%s %s%s %s%s %s%s ' % tuple('%012X' % self.value)

    def __str__(self):
        """
        生成打印格式的字符串
        """
        return '%s%s:%s%s:%s%s:%s%s:%s%s:%s%s' % tuple('%012x' % self.value)

    def __hash__(self):
        return self.value

    def __eq__(self, other):
        return self.value == other.value


class IP:
    used: Set[IP] = set()   # 使用过的 IP 地址

    @staticmethod
    def get_random():
        # return IP(random.randrange(16 ** 8))
        return IP(random.choice([
            0x0a000402, 0x0a000403, 0x0a000404, 0x0a000405
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

    def __hash__(self):
        return self.value

    def __eq__(self, other):
        return self.value == other.value


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
    if not parse_arguments():
        wrong_usage_exit()

    output = ''
    print('已生成 %d 条测试样例' %
          (Config.count))

    open(os.path.join(Config.path, 'arp_test.mem'), 'w').write(output)
