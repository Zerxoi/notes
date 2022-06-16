# 第二章 检测环境

## `CMAKE_SYSTEM_NAME` 操作系统检测

CMake 为目标操作系统定义了 `CMAKE_SYSTEM_NAME`，因此不需要使用定制命令、工具或脚本来查询此信息。使用 `CMAKE_SYSTEM_NAME` 变量的值实现特定于操作系统的条件和解决方案。

> 注：在具有 `uname` 命令的系统上，`CMAKE_SYSTEM_NAME` 变量将设置为 `uname -s` 的输出。

```cmake
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  message(STATUS "Configuring on/for Linux")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  message(STATUS "Configuring on/for macOS")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  message(STATUS "Configuring on/for Windows")
elseif(CMAKE_SYSTEM_NAME STREQUAL "AIX")
  message(STATUS "Configuring on/for IBM AIX")
else()
  message(STATUS "Configuring on/for ${CMAKE_SYSTEM_NAME}")
endif()
```

## `add_definitions` | `target_compile_definition` 添加定义

在代码中使用基于预处理器定义`IS_WINDOWS`、`IS_LINUX` 或 `IS_MACOS` 的条件编译:

```CXX
std::string say_hello() {
#ifdef IS_WINDOWS
  return std::string("Hello from Windows!");
#elif IS_LINUX
  return std::string("Hello from Linux!");
#elif IS_MACOS
  return std::string("Hello from macOS!");
#else
  return std::string("Hello from an unknown system!");
#endif
}
```

这些定义在 `CMakeLists.txt` 中配置时定义，通过使用`target_compile_definition` 或者 `add_definitions` 在预处理阶段使用。

使用 `add_definitions` 的缺点是，会修改编译整个项目的定义，而 `target_compile_definitions` 给我们机会，将定义限制于一个特定的目标，以及通过 `PRIVATE` | `PUBLIC` | `INTERFACE` 限定符，限制这些定义可见性。

- **PRIVATE**，编译定义将只应用于给定的目标，而不应用于相关的其他目标。
- **INTERFACE**，对给定目标的编译定义将只应用于使用它的目标。
- **PUBLIC**，编译定义将应用于给定的目标和使用它的所有其他目标。

在 CMakeLists.txt 中 CMake 根据系统名称为二进制目标设置对应编译器定义。

```cmake
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  target_compile_definitions(hello-world PUBLIC "IS_LINUX")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  target_compile_definitions(hello-world PUBLIC "IS_WINDOWS")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  target_compile_definitions(hello-world PUBLIC "IS_MACOS")
endif()
```

## `CMAKE_<LANG>_COMPILER_ID` 编译器检测

与 `CMAKE_SYSTEM_NAME` 类似，通过 `CMAKE_<LANG>_COMPILER_ID` 可以用于检测语言 `<LANG>` 所使用的编译器，并可以在编译期间为编译器添加特定编译器的定义实现为不同编译器生成不同的程序。

## `CMAKE_HOST_SYSTEM_PROCESSOR` 处理器架构

CMake 定义了 `CMAKE_HOST_SYSTEM_PROCESSOR` 变量，以包含当前运行的处理器的名称。可以设置为 `i386`、`i686`、 `x86_64`、`AMD64`等等。可以基于检测到的主机处理器体系结构，使用预处理器定义，确定需要编译的分支源代码。

## `CMAKE_SIZEOF_VOID_P` 指针大小

`CMAKE_SIZEOF_VOID_P` 为 `void` 指针的大小。使用 `CMAKE_SIZEOF_VOID_P` 是检查当前CPU是否具有32位或64位架构的唯一“真正”可移植的方法。

## `cmake_host_system_information` 查询主机系统的系统信息

```cmake
cmake_host_system_information(RESULT <variable> QUERY <key> ...)
```

查询运行 CMake 的宿主系统的系统信息。可以提供一个或多个 `<key>` 来选择要查询的信息。查询值列表存储在 `<variable>` 中。

## `configure_file` 配置文件

将文件复制到另一个位置并修改其内容。

```cmake
configure_file(<input> <output>
               [NO_SOURCE_PERMISSIONS | USE_SOURCE_PERMISSIONS |
                FILE_PERMISSIONS <permissions>...]
               [COPYONLY] [ESCAPE_QUOTES] [@ONLY]
               [NEWLINE_STYLE [UNIX|DOS|WIN32|LF|CRLF] ])
```

将 `<input>` 文件复制到 `<output>` 文件并替换输入文件内容中引用为 `@VAR@` 或 `${VAR}` 的变量值。每个变量引用都将替换为变量的当前值，如果未定义变量，则替换为空字符串。

## `find_package` 引入外部依赖包

参考：[Cmake之深入理解find_package()的用法](https://zhuanlan.zhihu.com/p/97369704)

为了方便我们在项目中引入外部依赖包，CMake 使用 `find_package` 指令来引入依赖。

- 在 `MODULE` 模式下使用时要寻找 `Find<LibraryName>.cmake` 文件。
  - 通常位于 `/usr/share/cmake/Modules` 目录下
- 在 `CONFIG` 模式下使用时，将在不同位置查找 `<LibrayName>Config.cmake` 文件
  - 通常位于 `/usr/lib/cmake` 目录下

## 编译器标志检测

`Check<LANG>CompilerFlag` 命令用于检查 `<LANG>` 编译器是否支持给定标志。

```cmake
check_cxx_compiler_flag(<flag> <var>)
```

这个函数接受两个参数:

- 第一个是要检查的编译器标志。
- 第二个是用来存储检查结果(`true` 或 `false`)的变量。

大多数处理器提供向量指令集，代码可以利用这些特性，获得更高的性能。由于线性代数运算可以从Eigen库中获得很好的加速，所以在使用Eigen库时，就要考虑向量化。我们所要做的就是，指示编译器为我们检查处理器，并为当前体系结构生成本机指令。不同的编译器供应商会使用不同的标志来实现这一点：GNU编译器使用 `-march=native` 标志来实现这一点，而Intel编译器使用`-xHost`标志。使用 `CheckCXXCompilerFlag.cmake` 模块提供的 `check_cxx_compiler_flag` 函数进行编译器标志的检查:

`check_cxx_compiler_flag("-march=native" _march_native_works)`
