import sys
import struct

'''
1:80002000 <UTEST_SIMPLE>:
2:8000200c <UTEST_1PTB>:
3:80002040 <UTEST_2DCT>:
4:80002088 <UTEST_3CCT>:
5:800020b4 <UTEST_4MDCT>:
'''

try:
    addr = int(sys.argv[1], 16)
except:
    print('Address invalid.')

# convert 32-bit int to byte string of length 4, from LSB to MSB
def int_to_byte_string(val):
    return struct.pack('<I', val)

with open('../../cpu_sv_test.mem', 'wb') as f:
    f.write(b'G')
    f.write(int_to_byte_string(addr))
