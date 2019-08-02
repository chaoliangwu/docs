
## 什么是AST
> 在计算机科学中，抽象语法树（Abstract Syntax Tree，AST），或简称语法树（Syntax tree），是源代码语法结构的一种抽象表示。它以树状的形式表现编程语言的语法结构。

AST 的功能十分强大。大名鼎鼎的`webpack` `babel`等前端工具都是借助AST来实现的。

AST在日常业务中也许很难涉及到。事实上，在javascript世界中，我们可以认为抽象语法树(AST)是最底层。 再往下，就是关于转换和编译的“黑魔法”领域了。

## AST的结构
说了这么多，我们来结合实例来看一下AST它到底长什么样子。

现在我们拆解一个简单的 add 函数
```jsx harmony
function add(a, b) {
    return a + b
}
```
-  首先，我们拿到的这个语法块，是一个函数声明`FunctionDeclaration`,接着拆解，它分为三块：
    - `id` 就是它的名字，add
    - `params` 两个参数，a和b
    - `body` 大括号里的内容
    
我们继续拆分，add 没法继续拆下去了，他是一个最基础的标记，就像是名字一样
```jsx harmony
{
    name: 'add'
    type: 'identifier'
    ...
}
```
params 继续拆分，其实就是两个`identifier`组成的数组，之后也没办法再拆分了。
```jsx harmony
[
    {
        name: 'a'
        type: 'identifier'
        ...
    },
    {
        name: 'b'
        type: 'identifier'
        ...
    }
]
```
接下来，我们拆分 body

body 其实是一个块状域`BlockStatement`，打开`BlockStatement`，里面是一个`ReturnStatement`

继续打开`ReturnStatement`,里面是一个二项式`BinaryExpression`，用来表示 `a + b`

继续打开`BinaryExpression`，它成了三部分，`left`，`operator`，`right`

- `operator` : +
- `left` :  a
- `right`:  b

到这里，我们把一个简单的add函数拆解完毕，它的全部构成为
```jsx harmony
{
  "type": "Program",
  "start": 0,
  "end": 39,
  "body": [
    {
      "type": "FunctionDeclaration",
      "start": 0,
      "end": 39,
      "id": {
        "type": "Identifier",
        "start": 9,
        "end": 12,
        "name": "add"
      },
      "expression": false,
      "generator": false,
      "params": [
        {
          "type": "Identifier",
          "start": 13,
          "end": 14,
          "name": "a"
        },
        {
          "type": "Identifier",
          "start": 16,
          "end": 17,
          "name": "b"
        }
      ],
      "body": {
        "type": "BlockStatement",
        "start": 19,
        "end": 39,
        "body": [
          {
            "type": "ReturnStatement",
            "start": 25,
            "end": 37,
            "argument": {
              "type": "BinaryExpression",
              "start": 32,
              "end": 37,
              "left": {
                "type": "Identifier",
                "start": 32,
                "end": 33,
                "name": "a"
              },
              "operator": "+",
              "right": {
                "type": "Identifier",
                "start": 36,
                "end": 37,
                "name": "b"
              }
            }
          }
        ]
      }
    }
  ]
}
```
看到这里，可能是要倒吸一口凉气。

我靠，转换一个add函数就这么费劲，出来这么一大坨，那我们成百上千行的代码要何从下手？

## 送我们的螺丝刀

不要着急，AST 纵然很复杂，但是现在不需要我们重复造轮子。关于AST的解析、操作、转换已经有很多成熟的库帮我们封装好了。

[Babel](https://www.babeljs.cn)就为我们封装好了一系列的工具。

另外，可以通过[AST explorer](https://astexplorer.net)来进行直观的树形结构转换。

接下来，让我们使用AST技术来实现一个自动为代码增加`try-catch`的babel插件！

[查看下文](/Learning/babelPlugin.html)
