# Testbench 说明

## 使用方法

- `thinpad_top.srcs/sim_1/runtime/scripts` 下存放生成测试用例的脚本，用 Python3 运行。`python3 xxx.py -?` 可以查看使用说明

- 脚本生成的 mem 文件已经添加到工程中，如果缺少则需要运行脚本生成。因为生成是随机的，所以生成的文件没有加入 git

## 关于文件读写

### 坑

Vivado 文件读写就是大坑，我花了一个晚上让 testbench 能够从文件中读取测试数据

遇到的错误信息在 Google 上完全搜不到，甚至 Vivado 一度提示我给客服提交 bug

以下是坑，环境 MacOS Mojave + Parallel Desktop + Win10

- 绝对路径是打不开文件的，什么姿势都打不开

- `$fopen` 打开的文件如果用 `$fread` 读要么报错，要么读出来全是 0

### 可行的文件读写方法

- 在 Vivado 里面添加 mem 文件作为 Simulation Sources，运行时 Vivado 就会把它自动拷贝到运行时目录

- 用 `$fscanf(file_descriptor, "%d %d", v1, v2)` 来读数据