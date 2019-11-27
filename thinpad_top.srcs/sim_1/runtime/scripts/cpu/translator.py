#!/usr/bin/env python
# -*- encoding=utf-8 -*-

import argparse
import math
import os
import platform
import re
import select
import socket
import string
import struct
import subprocess
import sys
import tempfile
from timeit import default_timer as timer
try:
    import serial
except:
    print("Please install pyserial")
    exit(1)
try:
    import readline
except:
    pass
try: type(raw_input)
except NameError: raw_input = input

CCPREFIX = "mips-mti-elf-"
if 'GCCPREFIX' in os.environ:
    CCPREFIX=os.environ['GCCPREFIX']
CMD_ASSEMBLER = CCPREFIX + 'as'
CMD_DISASSEMBLER = CCPREFIX + 'objdump'
CMD_BINARY_COPY = CCPREFIX + 'objcopy'

Reg_alias = ['zero', 'AT', 'v0', 'v1', 'a0', 'a1', 'a2', 'a3', 't0', 't1', 't2', 't3', 't4', 't5', 't6', 't7', 's0', 
                's1', 's2', 's3', 's4', 's5', 's6', 's7', 't8', 't9/jp', 'k0', 'k1', 'gp', 'sp', 'fp/s8', 'ra']

def test_programs():
    tmp = tempfile.NamedTemporaryFile()
    for prog in [CMD_ASSEMBLER, CMD_DISASSEMBLER, CMD_BINARY_COPY]:
        try:
            subprocess.check_call([prog, '--version'], stdout=tmp)
        except:
            print("Couldn't run", prog)
            print("Please check your PATH env", os.environ["PATH"].split(os.pathsep))
            tmp.close()
            return False
    tmp.close()
    return True

def output_binary(binary):
    if hasattr(sys.stdout,'buffer'): # Python 3
        sys.stdout.buffer.write(binary)
    else:
        sys.stdout.write(binary)

# convert 32-bit int to byte string of length 4, from LSB to MSB
def int_to_byte_string(val):
    return struct.pack('<I', val)

def byte_string_to_int(val):
    return struct.unpack('<I', val)[0]

# invoke assembler to compile instructions (in little endian MIPS32)
# returns a byte string of encoded instructions, from lowest byte to highest byte
# returns empty string on failure (in which case assembler messages are printed to stdout)
def multi_line_asm(instr):
    tmp_asm = tempfile.NamedTemporaryFile(delete=False)
    tmp_obj = tempfile.NamedTemporaryFile(delete=False)
    tmp_binary = tempfile.NamedTemporaryFile(delete=False)

    try:
        tmp_asm.write((instr + "\n").encode('utf-8'))
        tmp_asm.close()
        tmp_obj.close()
        tmp_binary.close()
        subprocess.check_output([
            CMD_ASSEMBLER, '-EL', '-mips32r2', tmp_asm.name, '-o', tmp_obj.name])
        subprocess.check_call([
            CMD_BINARY_COPY, '-j', '.text', '-O', 'binary', tmp_obj.name, tmp_binary.name])
        with open(tmp_binary.name, 'rb') as f:
            binary = f.read()
            return binary
    except subprocess.CalledProcessError as e:
        print(e.output)
    except:
        print("Unexpected error:", sys.exc_info()[0])
    finally:
        os.remove(tmp_asm.name)
        # object file won't exist if assembler fails
        if os.path.exists(tmp_obj.name):
            os.remove(tmp_obj.name)
        os.remove(tmp_binary.name)
    return ''

# invoke objdump to disassemble single instruction
# accepts encoded instruction (exactly 4 bytes), from least significant byte
# objdump does not seem to report errors so this function does not guarantee
# to produce meaningful result
def single_line_disassmble(binary_instr, addr):
    assert(len(binary_instr) == 4)
    tmp_binary = tempfile.NamedTemporaryFile(delete=False)
    tmp_binary.write(binary_instr)
    tmp_binary.close()

    raw_output = subprocess.check_output([
        CMD_DISASSEMBLER, '-D', '-b', 'binary',
        '--adjust-vma=' + str(addr),
        '-m', 'mips:isa32r2', tmp_binary.name])
    # the last line should be something like:
    #    0:   21107f00        addu    v0,v1,ra
    result = raw_output.strip().split(b'\n')[-1].split(None, 2)[-1]

    os.remove(tmp_binary.name)

    return result.decode('utf-8')


def run_T(num):
    if num < 0: #Print all entries
        start = 0
        entries = 16
    else:
        start = num
        entries = 1
    for i in range(start, start+entries):
        outp.write(b'T')
        outp.write(int_to_byte_string(i))

def run_A(addr):
    print("one instruction per line, empty line to end.")
    offset = addr & 0xfffffff
    prompt_addr = addr
    asm = ".set noreorder\n.set noat\n.org {:#x}\n".format(offset)
    while True:
        line = raw_input('[0x%04x] ' % prompt_addr).strip()
        if line == '':
            break
        elif re.match("\\w+:$", line) is not None:
            # ASM label only
            asm += line + "\n"
            continue
        try:
            asm += ".word {:#x}\n".format(int(line, 16))
        except ValueError:
            instr = multi_line_asm(".set noat\n" + line)
            if instr == '':
                continue
            asm += line + "\n"
        prompt_addr = prompt_addr + 4
    # print(asm)
    binary = multi_line_asm(asm)
    for i in range(offset, len(binary), 4):
        outp.write(b'A')
        outp.write(int_to_byte_string(addr))
        outp.write(int_to_byte_string(4))
        outp.write(binary[i:i+4])
        addr = addr + 4

def run_F(addr, file_name):
    if not os.path.isfile(file_name):
        print("file %s does not exist" % file_name)
        return
    print("reading from file %s" % file_name)
    offset = addr & 0xfffffff
    prompt_addr = addr
    asm = ".set noreorder\n.set noat\n.org {:#x}\n".format(offset)
    with open(file_name, "r") as f:
        for line in f:
            print('[0x%04x] %s' % (prompt_addr, line.strip()))
            if line == '':
                break
            elif re.match("\\w+:$", line) is not None:
                # ASM label only
                asm += line + "\n"
                continue
            try:
                asm += ".word {:#x}\n".format(int(line, 16))
            except ValueError:
                instr = multi_line_asm(".set noat\n" + line)
                if instr == '':
                    continue
                asm += line + "\n"
            prompt_addr = prompt_addr + 4
    binary = multi_line_asm(asm)
    for i in range(offset, len(binary), 4):
        outp.write(b'A')
        outp.write(int_to_byte_string(addr))
        outp.write(int_to_byte_string(4))
        outp.write(binary[i:i+4])
        addr = addr + 4


def run_R():
    outp.write(b'R')

def run_D(addr, num):
    if num % 4 != 0:
        print("num % 4 should be zero")
        return
    outp.write(b'D')
    outp.write(int_to_byte_string(addr))
    outp.write(int_to_byte_string(num))

def run_U(addr, num):
    if num % 4 != 0:
        print("num % 4 should be zero")
        return
    outp.write(b'D')
    outp.write(int_to_byte_string(addr))
    outp.write(int_to_byte_string(num))

def run_G(addr):
    outp.write(b'G')
    outp.write(int_to_byte_string(addr))

def MainLoop():
    while True:
        try:
            cmd = raw_input('>> ').strip().upper()
        except EOFError:
            break
        try:
            if cmd == 'Q':
                break
            elif cmd == 'A':
                addr = raw_input('>>addr: 0x')
                run_A(int(addr, 16))
            elif cmd == 'F':
                file_name = raw_input('>>file name: ')
                addr = raw_input('>>addr: 0x')
                run_F(int(addr, 16), file_name)
            elif cmd == 'R':
                run_R()
            elif cmd == 'D':
                addr = raw_input('>>addr: 0x')
                num = raw_input('>>num: ')
                run_D(int(addr, 16), int(num))
            elif cmd == 'U':
                addr = raw_input('>>addr: 0x')
                num = raw_input('>>num: ')
                run_U(int(addr, 16), int(num))
            elif cmd == 'G':
                addr = raw_input('>>addr: 0x')
                run_G(int(addr, 16))
            elif cmd == 'T':
                num = raw_input('>>num: ')
                run_T(int(num))
            else:
                print("Invalid command")
        except ValueError as e:
            print(e)

def InitializeFile(path):
    global outp
    outp = open(path, 'wb')

if __name__ == "__main__":
    InitializeFile('cpu_sv_test.mem')
    if not test_programs():
        exit(1)
    MainLoop()
    outp.close()