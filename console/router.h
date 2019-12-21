#ifndef __ROUTER_H__
#define __ROUTER_H__

#define ADDR_ROUTER_BASE 0xc0000000
#define ADDR_ROUTER_CNT 0xc0114514
#define ADDR_ROUTER_DATA 0xc0114518
#define ADDR_ROUTER_STATUS 0xc011451c

#include "utility.h"

typedef unsigned int u32;

typedef struct {
  u32 prefix;
  u32 nexthop;
  u32 mask;
  u32 metric;
} entry_t;

// 返回路由表数量
static u32 getEntryCount() { return CATCH(u32, ADDR_ROUTER_CNT) - 0x80000; }

// 返回第 index 个路由项的地址
static u32 getEntryAddress(u32 index) {
  return ADDR_ROUTER_BASE + 0x80000 + index * 16;
}

static void putDigit(u32 digit) {
  putc(digit + 48);
}

static void printIP(u32 ip) {
  printDecByte((ip >> 24) & 0xffu);
  putc('.');
  printDecByte((ip >> 16) & 0xffu);
  putc('.');
  printDecByte((ip >> 8) & 0xffu);
  putc('.');
  printDecByte(ip & 0xffu);
}

// 读取一条路由项
static entry_t getEntry(u32 index) {
  entry_t entry;
  u32 addr = getEntryAddress(index);
  entry.nexthop = CATCH(u32, addr + 4);
  entry.metric = CATCH(u32, addr + 8) & 0x1fu;
  u32 parent = ADDR_ROUTER_BASE + (CATCH(u32, addr) & 0xffffu) * 16;
  entry.prefix = CATCH(u32, parent + 4);
  entry.mask = CATCH(u32, parent + 8) & 0x3fu;
  return entry;
}

// 打印一条路由项，格式如下：
// 12.34.56.78/24  via  aa.bb.cc.dd  metric=6
static void printEntry(u32 index) {
  entry_t entry = getEntry(index);
  printIP(entry.prefix);
  putc('/');
  printDecByte(entry.mask);
  print("  via  ");
  printIP(entry.nexthop);
  print("  metric=");
  printDecByte(entry.metric);
  putc('\n');
}

// 打印所有的直连路由
static void printDirectRoute() {
  for (int i = 0; i < 4; i++) {
    entry_t entry = getEntry(i);
    printIP(entry.prefix);
    putc('/');
    printDecByte(entry.mask);
    print("  on port ");
    printDecByte(i + 1);
    putc('\n');
  }
}

// 打印所有路由
static void printRoute() {
  printDirectRoute();
  u32 count = getEntryCount();
  for (int i = 4; i < count; i++) {
    printEntry(i);
  }
}

#endif // __ROUTER_H__