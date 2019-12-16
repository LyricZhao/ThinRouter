import sys

fmt = lambda x: '%02x' % x

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Usage python3 bin2mem.py <input> (<output>)')
        exit()
    input = sys.argv[1]
    if len(sys.argv) > 2:
        output = open(sys.argv[2], 'w')
    else:
        output = None
    with open(input, 'rb') as f:
        data = f.read()
        num_inst = len(data) // 4
        for i in range(num_inst):
            le = data[i * 4: (i + 1) * 4]
            inst_str = fmt(le[3]) + fmt(le[2]) + fmt(le[1]) + fmt(le[0])
            if output:
                output.write(inst_str + '\n')
            else:
                print(inst_str)
    if output:
        output.close()