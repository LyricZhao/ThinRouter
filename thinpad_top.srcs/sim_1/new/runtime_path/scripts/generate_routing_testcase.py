"""
生成 routing table 的测试用例

输出会存储到 ../routing_test.data
格式：
    16 字节一条记录
    [0:3]   00 00 00 00 表示 insert
            00 00 00 01 表示 query
    [4:7]   80 00 00 01 表示查询/插入地址 128.0.0.1
    [8:11]  00 00 00 10 表示 mask 长度为 16 （query 时忽略）
    [12:15] 0a 00 00 01 表示 nexthop 地址 10.0.0.1 （query 时忽略）
"""
import random
import sys
import random
import os
import struct


class Config:
    insertion_count = 256   # how many insertions operation to make
    query_count = 1024      # how many queries operation to make
    miss_rate = 0.25        # the ratio of queries that would miss
    order = False           # whether all queries will be after insertions
    pressure = False        # whether inserted IP addresses are condense
    path = ''               # (maybe) relative path to runtime_path directory


class IPAddress:
    value: int  # uint32 value of IP address
    mask: int   # mask length, [12, 24]
    # if '-p', random generated IP addresses will be near this center
    center = random.randint(0, 0xffffffff)

    # generate random IP address
    def __init__(self, value: int = None, mask: int = None):
        if mask is None:
            self.mask = random.randint(12, 24)
        else:
            self.mask = mask
        if value is not None:
            self.value = value
        elif Config.pressure:
            self.value = int(random.normalvariate(
                IPAddress.center, 0x800000)) & 0xffffffff
        else:
            self.value = random.randint(0, 0xffffffff)
        # make values below mask all 0
        self.value ^= (self.value & (0xffffffff >> self.mask))

    @property
    def raw(self) -> bytearray:
        return struct.pack('>I', self.value)    # big-endian i32 value

    def __hash__(self):
        return self.value + hash(self.mask)

    def __eq__(self, other):
        return self.value == other.value and self.mask == other.mask

    def __str__(self):
        raw = self.raw
        return '%d.%d.%d.%d/%d' % (raw[0], raw[1], raw[2], raw[3], self.mask)


class Entry:
    inserted = set()    # inserted addresses

    @staticmethod
    def insert() -> bytearray:
        new_addr = IPAddress()
        while new_addr in Entry.inserted:
            new_addr = IPAddress()
        print('insert', new_addr)
        return new_addr.raw

    @staticmethod
    def query() -> bytearray:
        print("query")
        if random.random() < Config.miss_rate or len(Entry.inserted) == 0:
            return os.urandom(4)
        else:
            match = random.choice(Entry.inserted)
            rand_addr = random.randint(0, 0xffffffff)
            new_addr = match ^ (rand_addr & (0xffffffff >> match.mask))
            return struct.pack('>I', new_addr)


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

    output = b''
    for op in operations:
        if op == 'i':
            output += Entry.insert()
        else:
            output += Entry.query()

    open(os.path.join(Config.path, 'routing_test.data'), 'wb').write(output)
