## 关于babel

### Babel 是一个 JavaScript 编译器

Babel 是一个工具链，主要用于将 ECMAScript 2015+ 版本的代码转换为向后兼容的 JavaScript 语法，以便能够运行在当前和旧版本的浏览器或其他环境中。
```jsx harmony
// Babel 输入： ES2015 箭头函数
[1, 2, 3].map((n) => n + 1);

// Babel 输出： ES5 语法实现的同等功能
[1, 2, 3].map(function(n) {
  return n + 1;
});
```
### babel做了什么
babel 的转译过程也分为三个阶段，这三步具体是：
#### 解析 Parse
将代码解析生成抽象语法树( 即AST )。
#### 转换 Transform
对于 AST 进行变换一系列的操作，babel 接受得到 AST 并通过 babel-traverse 对其进行遍历，在此过程中进行添加、更新及移除等操作。
#### 生成 Generate
将变换后的 AST 再转换为 JS 代码, 使用到的模块是 babel-generator。


我们编写的 babel 插件则主要专注于第二步转换过程的工作，专注于对于代码的转化和拓展，解析与生成的偏底层相关操作则有对应的模块支持，在此我们理解它主要做了什么即可。

## 准备工作

正式开始之前，需要介绍两个概念：

### Visitors 访问者
访问者是一个用于 AST 遍历的跨语言的模式。
简单的说它们就是一个对象，定义了用于在一个树状结构中获取具体节点的方法。 这么说有些抽象，所以让我们来看一个例子
```jsx harmony
const MyVisitor = {
  Identifier(path) {
    console.log("Im Identifier");
  },
  FunctionDeclaration(path){
    console.log("Im FunctionDeclaration");
  }
};
```
这是一个简单的访问者，把它用于AST遍历中时，每当在树中遇见一个 `Identifier` 的时候会调用 `Identifier()` 方法，遇见一个 `FunctionDeclaration` 的时候则会调用 `FunctionDeclaration()`
方法。

### Paths 路径

`Visitors `
在遍历到每个节点的时候，
都会给我们传入 `path` 参数，
它包含了节点的信息以及节点和所在的位置，
供我们对特定节点进行修改。
之所以称之为 `path` 是其表示的是两个节点之间连接的对象，而非指当前的节点对象。

> 更具体的API可以查看[Babel插件手册](https://github.com/jamiebuilds/babel-handbook/blob/master/translations/zh-Hans/plugin-handbook.md#toc-paths)

### 插件格式
一个完整的插件格式如下
```jsx harmony
export default function({ types: t }) {
  return {
    pre(state) {  // 遍历之前 
         
    },
    visitor: { // 访问者
      VariableDeclaration(path) {
        // ... ...
      }
    },
    post(state) { // 遍历结束
      
    },
  };
}
```
### 注意
这里有一个值得注意的问题，所有的babel插件会共享同一次遍历过程。

也就是说，他们对节点的处理可能会相互影响。

比如我们需要对所有的方法添加 try-catch ,就需要定义一个FunctionDeclaration访用来访问所有的函数。


但是在其他插件里，比如babel-preset，它会生成一些辅助函数，这些辅助函数也会被我们的访问者访问。但我们只需要对源码进行处理。


想要避免对这些不在原始代码中的节点进行访问，笔者现在也没找到一个最好的方法，有以下尝试：

- 使用sourceMap，如果节点在sourceMap中找不到，则判断为生成的代码。
但sourceMap需要借助于webpack获取（或许存在更好的方法，但笔者还没找到，欢迎指正），这样插件配置起来比较复杂，并且通用性不够好。
- 借助`path.node.loc`。这个方法不准确，有些生成的节点也会含有location属性。
- 在节点开始遍历之前手动添加一次额外的遍历，我们处理完成后再交由其他插件处理。也是笔者目前在用的方法。目前来看比较准确，但需要一次额外的遍历开销。


## 开始
首先定义 Visitor 来访问方法声明
```jsx harmony
const funcVisitor = {
  FunctionDeclaration(path) {
    const functionBody = path.node.body; //获取方法的 body
    if (functionBody.type === 'BlockStatement') { // 含有block
      const body = functionBody.body; // 获取原来的block body
      path.get('body').replaceWith(wrapFunction({
        BODY: body,
        HANDLER:t.identifier('console.log')
      }))
    } 
  }
}
```

借助 [babel-template](https://www.babeljs.cn/docs/babel-template) 快速生成AST节点
```jsx harmony
const wrapFunction = template(`{
  try {
    BODY
  } catch(err) {
    HANDLER(err)
  }
}`);
```
接下来组装
```jsx harmony
const t = require('@babel/types');
const wrapFunction = template(`{
  try {
    BODY
  } catch(err) {
    HANDLER(err)
  }
}`);
const funcVisitor = {
  FunctionDeclaration(path) {
    const functionBody = path.node.body; //获取方法的 body
    if (functionBody.type === 'BlockStatement') { // 含有block
      const body = functionBody.body; // 获取原来的block body
      path.get('body').replaceWith(wrapFunction({
        BODY: body,
        HANDLER:t.identifier('console.log')
      }))
    } 
  }
}
module.exports = function () {
  return {
    pre(file){ // 开始遍历之前
      file.path.traverse(funcVisitor); // 插入额外的遍历
    }
  };
};
```
## 使用
`webpack.config.js`

```jsx harmony
const myPlugin = require('xxx')
module: {
    rules: [
      {
        test: /\.js$/,
        exclude:/node_modules/,//排除掉node_module目录
        loader:'babel-loader',
        options:{
          plugins:[myPlugin]
        },
      },
    ]
  },
```
测试一下，输入代码
```jsx harmony
function Foo(){
  console.log('Im foo')
}
```
输出为
```jsx harmony
function Foo(){
  try{
   console.log('Im foo') 
  }catch (err) {
    console.error(err)
  }
}
```
一个简单的为方法声明增加try-catch的babel插件就开发完成了。但它也就仅仅能够应付测试中的简单情况。

笔者已经写好了一个相对完善的插件，它可以为`Promise`添加`.catch`，也可以对 **方法声明** | **类方法** 注入捕获语句。配置也相对灵活，支持目录以及文件筛选。

不完善的地方欢迎大家补充~

[源码传送门](https://github.com/7revor/babel-plugin-promise-catcher)
