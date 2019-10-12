# Testbench 说明

### 关于文件目录（重要）

运行时如果需要读取文件，当前目录会在一个临时目录中，因此助教的建议是在代码中写入绝对路径。

为了方便大家统一使用，每个人应当在 `thinpad_top.srcs/sim_1/new/include/path.vh` 中写入在自己系统中 `thinpad_top.srcs/sim_1/new/runtime_path` 的绝对路径，样例如下：

```verilog
// path.vh
`define RUNTIME_PATH "/usr/some/path"
```

如果需要在代码中打开文件，样例如下：

```verilog
`include "path.vh"
integer file_descriptor;
file_descriptor = $fopen({RUNTIME_PATH, "/something.log"}, "w");
```

注意到，为了在每台设备上不一样，`path.vh` **被 `.gitignore` 排除在 git 之外**，因此需要手动添加并修改