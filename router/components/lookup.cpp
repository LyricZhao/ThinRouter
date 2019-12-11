// TODO: 改成C实现

# include "lookup.h"
# include "../include/rip_pack.h"
# include <map>

extern "C" {
std:: map<uint32_t, RoutingTableEntry> table[33];

/*
  RoutingTable Entry 的定义如下：
  typedef struct {
    uint32_t addr; // 大端序，IPv4 地址
    uint32_t len; // 小端序，前缀长度
    uint32_t if_index; // 小端序，出端口编号
    uint32_t nexthop; // 大端序，下一跳的 IPv4 地址
  } RoutingTableEntry;

  约定 addr 和 nexthop 以 **大端序** 存储。
  这意味着 1.2.3.4 对应 0x04030201 而不是 0x01020304。
  保证 addr 仅最低 len 位可能出现非零。
  当 nexthop 为零时这是一条直连路由。
  你可以在全局变量中把路由表以一定的数据结构格式保存下来。
*/

/**
 * @brief 插入/删除一条路由表表项
 * @param insert 如果要插入则为 true ，要删除则为 false
 * @param entry 要插入/删除的表项
 *
 * 插入时如果已经存在一条 addr 和 len 都相同的表项，则替换掉原有的。
 * 删除时按照 addr 和 len 匹配。
 */
void update(uint8_t insert, RoutingTableEntry entry) {
    uint32_t addr = htonl(entry.addr);
    for (int i = 0; i <= 32 - entry.len; i++) addr &= ~(1u << i); // 低位置0
    if (insert) {
        table[entry.len][addr] = entry;
    } else {
        table[entry.len].erase(addr);
    }
}

/**
 * @brief 进行一次路由表的查询，按照最长前缀匹配原则
 * @param addr 需要查询的目标地址，大端序
 * @param nexthop 如果查询到目标，把表项的 nexthop 写入
 * @param if_index 如果查询到目标，把表项的 if_index 写入
 * @param metric 如果查询到目标，把表项的 metric 写入
 * @return 查到则返回 true ，没查到则返回 false
 */
uint8_t query(uint32_t addr, uint32_t *nexthop, uint32_t *if_index, uint32_t *metric) {
    addr = htonl(addr);
    for (int i = 32; ~ i; -- i) {
        if (table[i].count(addr)) {
            RoutingTableEntry entry = table[i][addr];
            *nexthop = entry.nexthop, *if_index = entry.if_index, *metric = entry.metric;
            return true;
        }
        addr &= ~(1u << (32 - i));
    }
    return false;
}

/**
 * @brief 当收到rip的request时，把路由表项封装成RipPacket传回去
 * @param src_ip IN 源IP，大端序
 * @param if_index IN 即将发回的端口号
 * @param output OUT 组装成的RipPacket
 * @param packet_num OUT 当前表项需要组成多少个包
 * @return 路由表项的条数
 */
void assemble_rip(uint32_t src_ip, uint32_t if_index, RipPacket *output, uint32_t *packet_num) {
    // 遍历路由表，封装所有和源ip地址不在同一网段的路由表项到RIP报文里，填充Rip报文，command为字段2
    // 详见《路由器实验开发指南.pdf》 4.4.2<4>
    uint32_t cur_entry = 0; // 当前entry条数
    *packet_num = 0;
    src_ip = htonl(src_ip); // 转换成小端序
    for (int i = 32; ~i; -- i) {
        for (auto &entry : table[i]) {
            if (entry.second.addr == src_ip || entry.second.if_index == if_index) {
                // 目的地址与源IP在同一网段中，或者if_index相同，略过
            } else {
                if (cur_entry >= 25) { // 达到25条，放入下一个rip packet
                    output[*packet_num].command = 2;
                    output[*packet_num].numEntries = 25;
                    cur_entry = 0;
                    *packet_num++;
                }
                output[*packet_num].entries[cur_entry] = {
                    .addr = entry.second.addr,
                    .mask = entry.second.len,
                    .nexthop = entry.second.nexthop,
                    .metric = entry.second.metric
                };
                cur_entry++;
            }
        }
        src_ip &= ~(1u << (32 - i));
    }
    output[*packet_num].command = 2;
    output[*packet_num].numEntries = cur_entry; // !有可能出现0个表项的rip包
    *packet_num++;
}
}