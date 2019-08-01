## 引言
现代前端应用面临的浏览器环境是非常复杂的，尤其是移动端页面。

面对如此多样的浏览器环境，我们需要一种异常监控机制，在页面上有异常发生时，能够获得错误的基本信息、文件url、行号等。接下来我们探讨几种实现全局异常捕获的实现方式。

## try-catch
这个方法最简单粗暴，我们都写过`try-catch`。将可能会出错的代码使用`try-catch`包裹，就可以捕获到其中的错误：
```jsx harmony
function foo(){
  try{
    ... ...
  }catch (e) {
    console.error(e)
  }
}
```
缺点也很明显，我们不确定哪些地方会出错，并且随着项目体积的增大，`try-catch`的代价也与日俱增。

## 全局捕获
好在浏览器为我们提供了全局的`window.onerror`事件，我们可以使用它来搜集页面上的错误：

```jsx harmony
window.onerror = function(message, source, lineno, colno, error) { 
  ... ...
 }
```
其中
- `mesage` 异常基本信息
- `source` 为发生异常的文件地址
- `lineno` 错误行号

这种方式看似完美，其实有三个致命的问题。
- 由于浏览器的同源策略，当加载自不同域（协议、域名、端口三者任一不同）的脚本中发生语法错误时，为避免信息泄露，语法错误的细节将不会报告，而代之简单的`Script error`
- 我们发布到生产环境中的代码，往往都经过压缩混淆，文件名、函数名、变量名已经不具有可读性了需要借助`sourceMap`定位错误。
- 无法捕获`Promise`中的异常

## 未处理的Promise异常
使用`Promise`编写异步代码时，使用`reject`来处理错误。有时，开发者通常会忽略这一点，导致一些错误没有得到处理。

一些浏览器(例如Chrome)能够捕获未处理的Promise错误。

- 监听`unhandledrejection`事件，即可捕获到未处理的`Promise`错误：
```jsx harmony
window.addEventListener('unhandledrejection', event => ···);
```

## 使用AST自动为函数以及Promise添加捕获
像我们上面所提到的，随着项目体积的逐渐增加，对每一个函数都手动添加`try-catch`无疑是一个巨大的工作量。

那么有没有“偷懒”的方法呢？

答案是肯定的。接下来我们介绍一种通过操作`AST`(抽象语法树)来为所有函数以及`Promise`添加捕获的方法。

[查看下文](/Learning/ast.html)
