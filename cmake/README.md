# 第一章 从可执行文件到库

参考：[CMake菜谱](https://github.com/xiaoweiChen/CMake-Cookbook)

## `cmake_minimum_required` 最低版本

设置CMake所需的最低版本。如果使用的CMake版本低于该版本，则会发出致命错误：

```cmake
cmake_minimum_required(VERSION 3.5 FATAL_ERROR)
```

## `project` 项目名

声明了项目的名称(`project_name`)和支持的编程语言(`CXX` 代表C++)：

```cmake
project(project_name LANGUAGES CXX)
```

## `add_executable` 构建可执行文件

指示CMake创建一个新目标：**可执行文件** `hello-world`。这个可执行文件是通过编译和链接源文件 `hello-world.cpp` 生成的。

> CMake将为编译器使用默认设置，并自动选择生成工具

```cmake
add_executable(hello-world hello-world.cpp)
```

## 构建系统生成

```bash
$ tree
.
├── build (directory)
├── CMakeLists.txt (file)
└── hello-world.cpp (file)

1 directory, 2 files
$ cd build && cmake ..
-- The CXX compiler identification is GNU 12.1.0
-- Detecting CXX compiler ABI info
-- Detecting CXX compiler ABI info - done
-- Check for working CXX compiler: /usr/sbin/c++ - skipped
-- Detecting CXX compile features
-- Detecting CXX compile features - done
-- Configuring done
-- Generating done
```

CMake是一个**构建系统生成器**。生成的构建系统(如：`Unix Makefile`、`Ninja`、`Visual Studio` 等)将包含为给定项目构建目标文件、可执行文件和库的目标及规则。然后，CMake为所选的构建系统生成相应的指令。默认情况下，在 GNU/Linux 和 macOS 系统上，CMake使用 `Unix Makefile` 生成器。Windows 上，`Visual Studio` 是默认的生成器。

GNU/Linux上，CMake默认生成Unix Makefile来构建项目：

- `Makefile`: `make` 将运行指令来构建项目。
- `CMakefile`：包含临时文件的目录，CMake用于检测操作系统、编译器等。此外，根据所选的生成器，它还包含特定的文件。
- `cmake_install.cmake`：处理安装规则的CMake脚本，在项目安装时使用。
- `CMakeCache.txt`：如文件名所示，CMake缓存。CMake在重新运行配置时使用这个文件。

## 构建系统

```bash
# 构建生成文件目录
$ ls
CMakeCache.txt  CMakeFiles  cmake_install.cmake  Makefile
# 开始构建
$ cmake --build .
[ 50%] Building CXX object CMakeFiles/hello-world.dir/hello-world.cpp.o
[100%] Linking CXX executable hello-world
[100%] Built target hello-world
```

CMake生成的目标比构建可执行文件的目标要多。通过如下命令可以查看能够构建的目标。

```bash
$ cmake --build . --target help
The following are some of the valid targets for this Makefile:
... all (the default if no target is provided)
... clean
... depend
... rebuild_cache
... hello-world
... edit_cache
... hello-world.o
... hello-world.i
... hello-world.s
```

可以使用 `cmake --build . --target <target-name>` 语法，实现如下功能：

- `all`(或Visual Studio generator中的ALL_BUILD)是默认目标，将在项目中构建所有目标。
- `clean`，删除所有生成的文件。
- `rebuild_cache`，将调用CMake为源文件生成依赖(如果有的话)。
- `edit_cache`，这个目标允许直接编辑缓存。

## 切换生成器

CMake是一个构建系统生成器，可以使用单个 `CMakeLists.txt` 为不同平台上的不同工具集配置项目。您可以在 `CMakeLists.txt` 中描述构建系统必须运行的操作，以配置并编译代码。基于这些指令，CMake将为所选的构建系统(Unix Makefile、Ninja、Visual Studio等等)生成相应的指令。

用以下命令，可在平台上找到生成器名单，以及已安装的CMake版本：

```bash
$ cmake --help
Generators
The following generators are available on this platform:
Unix Makefiles = Generates standard UNIX makefiles.
Ninja = Generates build.ninja files.
Watcom WMake = Generates Watcom WMake makefiles.
CodeBlocks - Ninja = Generates CodeBlocks project files.
CodeBlocks - Unix Makefiles = Generates CodeBlocks project files.
CodeLite - Ninja = Generates CodeLite project files.
CodeLite - Unix Makefiles = Generates CodeLite project files.
Sublime Text 2 - Ninja = Generates Sublime Text 2 project files.
Sublime Text 2 - Unix Makefiles = Generates Sublime Text 2 project files.
Kate - Ninja = Generates Kate project files.
Kate - Unix Makefiles = Generates Kate project files.
Eclipse CDT4 - Ninja = Generates Eclipse CDT 4.0 project files.
Eclipse CDT4 - Unix Makefiles= Generates Eclipse CDT 4.0 project files.
```

切换生成器步骤如下：

```bash
# 用-G切换生成器。
$ cmake -G Ninja ..
-- The CXX compiler identification is GNU 8.1.0
-- Check for working CXX compiler: /usr/bin/c++
-- Check for working CXX compiler: /usr/bin/c++ -- works
-- Detecting CXX compiler ABI info
-- Detecting CXX compiler ABI info - done
-- Detecting CXX compile features
-- Detecting CXX compile features - done
-- Configuring done
-- Generating done
# 构建项目
$ cmake --build .
[2/2] Linking CXX executable hello-world
```

## `add_library` 构建库

`add_library` 是生成必要的构建指令，将指定的源码编译到库中。`add_library` 的第一个参数是目标名。整个 `CMakeLists.txt` 中，可使用相同的名称来引用库。生成的库的实际名称将由CMake通过在前面添加前缀 `lib` 和适当的扩展名作为后缀来形成。生成库是根据第二个参数( `STATIC` 或 `SHARED` )和操作系统确定的。

```cmake
add_library(<name> [STATIC | SHARED | MODULE]
             [EXCLUDE_FROM_ALL]
             [<source>...])
```

CMake接受其他值作为add_library的第二个参数的有效值，我们来看下本书会用到的值：

- `STATIC`：用于创建静态库，即编译文件的打包存档，以便在链接其他目标时使用，例如：可执行文件。
- `SHARED`：用于创建动态库，即可以动态链接，并在运行时加载的库。可以在 `CMakeLists.txt` 中使用`add_library(<name> SHARED [<source>...])`从静态库切换到动态共享对象(DSO)。
- `OBJECT`：可将给定 `add_library` 的列表中的源码编译到目标文件，不将它们归档到静态库中，也不能将它们链接到共享对象中。
  - 如果需要一次性创建静态库和动态库，那么使用对象库尤其有用。  

    ```cmake
    add_library(message-objs
        OBJECT
            Message.hpp
            Message.cpp
        )
    # this is only needed for older compilers
    # but doesn't hurt either to have it
    set_target_properties(message-objs
        PROPERTIES
            POSITION_INDEPENDENT_CODE 1
        )
    add_library(message-shared
        SHARED
            $<TARGET_OBJECTS:message-objs>
        )
    ```

- `MODULE`：又为DSO组。与`SHARED`库不同，它们不链接到项目中的任何目标，不过可以进行动态加载。该参数可以用于构建运行时插件。

## `target_link_libraries` 链接库

`target_link_libraries(hello-world message)` 将 `message` 库链接到 `hello-world` 可执行文件。此命令还确保 `hello-world` 可执行文件可以正确地依赖于`message`库。因此，在消息库链接到 `hello-world` 可执行文件之前，需要完成消息库的构建。

## `if() ... endif()` 条件语句控制编译

```bash
if(<condition>)
  <commands>
elseif(<condition>) # optional block, can be repeated
  <commands>
else()              # optional block
  <commands>
endif()
```

## `option` 编译选项

`option` 可接受三个参数：

```bash
option(<option_variable> "help string" [initial value])
```

- `<option_variable>`表示该选项的变量的名称。
- `"help string"`记录选项的字符串，在CMake的终端或图形用户界面中可见。
- `[initial value]`选项的默认值，可以是`ON`或`OFF`。

## `cmake_dependent_option` 选项依赖

有时选项之间会有依赖的情况。示例中，我们提供生成静态库或动态库的选项。但是，如果没有将`USE_LIBRARY`逻辑设置为`ON`，则此选项没有任何意义。CMake提供`cmake_dependent_option()`命令用来定义依赖于其他选项的选项：

```cmake
include(CMakeDependentOption)

# second option depends on the value of the first
cmake_dependent_option(
  MAKE_STATIC_LIBRARY "Compile sources into a static library" OFF "USE_LIBRARY"
  ON)

# third option depends on the value of the first
cmake_dependent_option(
  MAKE_SHARED_LIBRARY "Compile sources into a shared library" ON "USE_LIBRARY"
  ON)
```

CMake有适当的机制，通过包含模块来扩展其语法和功能，这些模块要么是CMake自带的，要么是定制的。本例中，包含了一个名为`CMakeDependentOption`的模块。如果没有`include`这个模块，`cmake_dependent_option()`命令将不可用。

## `CMAKE_<LANG>_COMPILER` 指定编译器

CMake将语言的编译器存储在 `CMAKE_<LANG>_COMPILER` 变量中，其中 `<LANG>` 是受支持的任何一种语言，对于我们的目的是 `CXX` 、`C` 或 `Fortran` 。用户可以通过以下两种方式之一设置此变量：

1. 使用CLI中的`-D`选项，例如：

   ```shell
   cmake -D CMAKE_CXX_COMPILER=clang++ ..
   ```

2. 通过导出环境变量`CXX`(C++编译器)、`CC`(C编译器)和`FC`(Fortran编译器)。例如，使用这个命令使用`clang++`作为`C++`编译器：

   ```shell
   env CXX=clang++ cmake ..
   ```

**NOTE**:*CMake了解运行环境，可以通过其CLI的`-D`开关或环境变量设置许多选项。前一种机制覆盖后一种机制，但是我们建议使用`-D`显式设置选项。显式优于隐式，因为环境变量可能被设置为不适合(当前项目)的值。*

## `--system-information` 系统信息

CMake提供`--system-information`标志，它将把关于系统的所有信息转储到屏幕或文件中。要查看这个信息，请尝试以下操作：

```shell
cmake --system-information information.txt
```

文件中(本例中是`information.txt`)可以看到`CMAKE_CXX_COMPILER`、`CMAKE_C_COMPILER`和`CMAKE_Fortran_COMPILER`的默认值，以及默认标志。我们将在下一个示例中看到相关的标志。

CMake提供了额外的变量来与编译器交互：

- `CMAKE_<LANG>_COMPILER_LOADED`:如果为项目启用了语言`<LANG>`，则将设置为`TRUE`。
- `CMAKE_<LANG>_COMPILER_ID`:编译器标识字符串，编译器供应商所特有。例如，`GCC`用于GNU编译器集合，`AppleClang`用于macOS上的Clang, `MSVC`用于Microsoft Visual Studio编译器。注意，不能保证为所有编译器或语言定义此变量。
- `CMAKE_COMPILER_IS_GNU<LANG>`:如果语言`<LANG>`是GNU编译器集合的一部分，则将此逻辑变量设置为`TRUE`。注意变量名的`<LANG>`部分遵循GNU约定：C语言为`CC`, C++语言为`CXX`, Fortran语言为`G77`。
- `CMAKE_<LANG>_COMPILER_VERSION`:此变量包含一个字符串，该字符串给定语言的编译器版本。版本信息在`major[.minor[.patch[.tweak]]]`中给出。但是，对于`CMAKE_<LANG>_COMPILER_ID`，不能保证所有编译器或语言都定义了此变量。

## `CMAKE_BUILD_TYPE` 构建类型

CMake可以配置构建类型，例如：Debug、Release等。配置时，可以为Debug或Release构建设置相关的选项或属性，例如：编译器和链接器标志。控制生成构建系统使用的配置变量是`CMAKE_BUILD_TYPE`。该变量默认为空，CMake识别的值为:

1. **Debug**：用于在没有优化的情况下，使用带有调试符号构建库或可执行文件。
2. **Release**：用于构建的优化的库或可执行文件，不包含调试符号。
3. **RelWithDebInfo**：用于构建较少的优化库或可执行文件，包含调试符号。
4. **MinSizeRel**：用于不增加目标代码大小的优化方式，来构建库或可执行文件。

## 设置编译器选项

CMake为调整或扩展编译器标志提供了很大的灵活性，您可以选择下面两种方法:

- CMake将编译选项视为目标属性。因此，可以根据每个目标设置编译选项，而不需要覆盖CMake默认值。
  - 使用 CMake 的 `target_compile_options` 命令设置目标的编译选项。例如 `target_compile_options(compute-areas PRIVATE "-fPIC")`
  - 编译选项可以添加三个级别的可见性：`INTERFACE`、`PUBLIC`和`PRIVATE`。
    - **PRIVATE**，编译选项会应用于给定的目标，不会传递给与目标相关的目标。我们的示例中， 即使`compute-areas`将链接到`geometry`库，`compute-areas`也不会继承`geometry`目标上设置的编译器选项。
    - **INTERFACE**，给定的编译选项将只应用于指定目标，并传递给与目标相关的目标。
    - **PUBLIC**，编译选项将应用于指定目标和使用它的目标。
- 可以使用 `-D` 标志直接修改`CMAKE_<LANG>_FLAGS_<CONFIG>`变量。这将影响项目中的所有目标，并覆盖或扩展CMake默认值。
  - 例如，C++ 的 Release 构建类型的编译器选项`CMAKE_CXX_FLAGS_RELEASE`的默认值为 `"-O3 -DNDEBUG"`，可以手动修改并覆盖。

## 设置构建对象标准

使用 `set_target_properties` 设置构建的对象的标准。例如：

```cmake
set_target_properties(
  animals
  PROPERTIES CXX_STANDARD 14
             CXX_EXTENSIONS OFF
             CXX_STANDARD_REQUIRED ON)
```

为 `animals` 库目标设置了一些属性:

- **CXX_STANDARD**会设置我们想要的标准。
- **CXX_EXTENSIONS**告诉CMake，只启用`ISO C++`标准的编译器标志，而不使用特定编译器的扩展。
- **CXX_STANDARD_REQUIRED**指定所选标准的版本。如果这个版本不可用，CMake将停止配置并出现错误。当这个属性被设置为`OFF`时，CMake将寻找下一个标准的最新版本，直到一个合适的标志。这意味着，首先查找`C++14`，然后是`C++11`，然后是`C++98`。（译者注：目前会从`C++20`或`C++17`开始查找）

## 循环遍历

CMake还提供了创建循环的语言工具：`foreach endforeach`和`while-endwhile`。两者都可以与`break`结合使用，以便尽早从循环中跳出。本示例将展示如何使用`foreach`，来循环源文件列表。

`foreach()`的四种使用方式:

- `foreach(loop_var arg1 arg2 ...)`: 其中提供循环变量和显式项列表。注意，如果项目列表位于变量中，则必须显式展开它；也就是说，`${list_variable}`必须作为参数传递。
- 通过指定一个范围，可以对整数进行循环，例如：`foreach(loop_var range total)`或`foreach(loop_var range start stop [step])`。
- 对列表值变量的循环，例如：`foreach(loop_var IN LISTS [list1[...]])` 。参数解释为列表，其内容就会自动展开。
- 对变量的循环，例如：`foreach(loop_var IN ITEMS [item1 [...]])`。参数的内容没有展开。
