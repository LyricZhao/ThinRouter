"""
生成 arp 的测试用例

输出会存储到 ../arp_test.mem
插入:   ip -> mac@port （port 为接口 0123）
    insert  128.0.0.1 -> 48:aa:bb:cc:ee:ff/3
查询:   ip -> mac@port （mac = 00:00:00:00:00:00@0 表示无法匹配任一表项）
    query   128.0.0.1 -> 48:aa:bb:cc:ee:ff/3
结束:   end
    end

生成的地址不会为 0.0.0.0 或 00:00:00:00:00:00
"""
from __future__ import annotations
from typing import *
import random
import sys
import random
import os
import struct
import json


class Config:
    insertion_count = 4     # how many insertions operation to make
    query_count = 256       # how many queries operation to make
    miss_rate = 0.5         # the ratio of queries that would miss
    order = False           # whether all queries will be after insertions
    pressure = False        # whether inserted IP addresses are condense
    path = ''               # (maybe) relative path to runtime_path directory


def MAC():
    return '%02x:%02x:%02x:%02x:%02x:%02x@%d' % (*list(os.urandom(6)), random.randint(1, 4))


class IPAddress:
    value: int  # uint32 value of IP address
    mac: str    # mac address string
    # if '-p', random generated IP addresses will be near this center
    center: int = random.randint(0, 0xffffffff)

    @staticmethod
    def get_insert_addr() -> IPAddress:
        """
        随机生成一个带有 mask 的地址
        如果在 -p 模式下，生成的地址会集中在一个比较小的范围
        """
        value = 0
        while value == 0:
            if Config.pressure:
                value = int(random.normalvariate(
                    IPAddress.center, 0x800000)) & 0xffffffff
            else:
                value = random.randint(0, 0xffffffff)
        return IPAddress(value)

    @staticmethod
    def get_random_addr() -> IPAddress:
        """
        随机生成一个地址
        """
        return IPAddress(random.randint(1, 0xffffffff))

    def __init__(self, value: int):
        self.value = value
        self.mac = None

    @property
    def raw(self) -> bytearray:
        return struct.pack('>I', self.value)    # big-endian i32 value

    def __getitem__(self, index) -> int:
        if type(index) is not int:
            raise TypeError()
        return self.raw[index]

    def __hash__(self):
        return self.value

    def __eq__(self, other):
        return self.value == other.value

    def __str__(self):
        raw = self.raw
        return '%d.%d.%d.%d' % (raw[0], raw[1], raw[2], raw[3])


class Entry:
    inserted = set()    # 已经插入的地址
    inserted_list = []  # 已经插入的地址（用于随机选择）
    counter = 0         # 已经生成的条目数量

    @staticmethod
    def _save(addr: IPAddress):
        """
        将一个被插入的条目保存
        """
        if addr in Entry.inserted:
            raise Exception()
        Entry.inserted.add(addr)
        Entry.inserted_list.append(addr)

    @staticmethod
    def insert() -> str:
        """
        生成一条插入的数据
        """
        new_addr = IPAddress.get_insert_addr()
        while new_addr in Entry.inserted:
            new_addr = IPAddress.get_insert_addr()
        new_addr.mac = MAC()
        Entry._save(new_addr)
        Entry.counter += 1
        return 'insert  %s -> %s\n' % (new_addr, new_addr.mac)

    @staticmethod
    def query() -> str:
        if random.random() < Config.miss_rate or len(Entry.inserted) == 0:
            addr = IPAddress.get_random_addr()
        else:
            addr = random.choice(Entry.inserted_list)
        Entry.counter += 1
        if addr.mac is not None:
            return 'query   %s -> %s\n' % (addr, addr.mac)
        else:
            return 'query   %s -> 00:00:00:00:00:00@0\n' % addr


def wrong_usage_exit():
    print('\033[31mInvalid arguments\033[0m')
    print(
        'Arguments:',
        '-i <insert_count>',
        '\tSpecify how many routing entry to insert. Default is %d.' % Config.insertion_count,
        '-q <query_count>',
        '\tSpecify how many queries to make. Default is %d.' % Config.query_count,
        '-m <miss_rate>',
        '\tSpecify the ratio of queries that doesn\'t match any insertion. Default is %.2f.' % Config.miss_rate,
        '-o | --order',
        '\tIf given, all queries will be ordered after insertions.',
        '-p | --pressure',
        '\tIf given, inserted IP addresses will be condensed in a smaller range.', sep='\n')
    exit(0)


def parse_arguments() -> bool:
    state = ''
    try:
        # get path
        scripts_path = os.path.dirname(sys.argv[0])
        Config.path = os.path.normpath(os.path.join(scripts_path, '..'))
        # parse arguments
        for v in sys.argv[1:]:
            if state == '':
                if v == '-i':
                    state = 'i'
                elif v == '-q':
                    state = 'q'
                elif v == '-m':
                    state = 'm'
                elif v == '-o' or v == '--order':
                    Config.order = True
                elif v == '-p' or v == '--pressure':
                    Config.pressure = True
                else:
                    return False
            elif state == 'i':
                Config.insertion_count = int(v)
                if Config.insertion_count < 0:
                    return False
                state = ''
            elif state == 'q':
                Config.query_count = int(v)
                if Config.query_count < 0:
                    return False
                state = ''
            elif state == 'm':
                Config.miss_rate = float(v)
                if not 0 <= Config.miss_rate <= 1:
                    return False
                state = ''
        return state == ''
    except (ValueError):
        return False


if __name__ == '__main__':
    if not parse_arguments():
        wrong_usage_exit()

    operations = ['i'] * Config.insertion_count + ['q'] * Config.query_count
    if not Config.order:
        random.shuffle(operations)

    output = ''
    for op in operations:
        if op == 'i':
            output += Entry.insert()
        else:
            output += Entry.query()

    output += 'end\n'

    print('已生成测试样例，共 %d 条插入，%d 条查询' %
          (Config.insertion_count, Config.query_count))

    open(os.path.join(Config.path, 'arp_test.mem'), 'w').write(output)
