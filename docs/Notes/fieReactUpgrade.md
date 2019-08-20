## 升级动机

工作中两款插件都是使用 [fie-toolkit-qnui](https://github.com/fieteam/fie-toolkit-qnui)套件进行开发。使用中发现了它的弊端：

- 内置的 React 版本是 `15.6`，而现在 React 已经迭代带到 `16.9`。新版的 React 肯定比旧版的更快，更稳定。并且很多优秀的API（比如笔者最喜欢的[Hooks](https://zh-hans.reactjs.org/docs/hooks-intro.html)）老版本自然是无法使用。
- fie 在开发环境下仍然使用 `production.min.js` 。这将会忽略 **语法检查** 和 **性能提示**，不利于我们构建更好更快的应用。
- 生产模式下的`ReactDom`渲染异常报错，没有任何的错误以及堆栈信息，有的只是网页链接，打开后才会显示我们的错误信息。但这对debug没有丝毫帮助。代码这么多，完全不知道是哪里的问题。


这就让下定了升级React的决心。

这么简单的问题肯定不止笔者一个人想到，于是乎兴冲冲的跑去 github 看看有没有人提 issue，
但结果让我很是震惊。

fie 的最后更新时间是两年之前，而脚手架配套的[QNUI](https://github.com/INTL-Alibaba/qnui)组件库,也同样是两年没有更新了。

看他们的 github 发现项目组得人都跑去隔壁做 [FusionDesign](https://fusion.design)了。。。🤣

想要换架构肯定是不可能了，动辄上万行代码，成本实在是难以预估。。

只有自己琢磨琢磨升级方法了。

## 升级过程

脚手架升级表现倒还令人满意，修改`package.json`，执行 `npm install`，整个过程一气呵成，也没遇到啥报错。

启动服务后打开页面，wait！！！不是升级了吗，怎么还是 15.6 ,也没有任何提示？！！

### 1# 坑
观察`webpack.confog.js`我们可以发现
```jsx harmony
 externals: {
     'react': 'React',
      'react-dom': 'ReactDOM',
      'react-redux': 'ReactRedux',
      'react-router': 'ReactRouter',
      'react-router-redux': 'ReactRouterRedux',
      'redux-thunk': 'var window.ReduxThunk.default',
      'redux': 'Redux',
      'qnui': 'qnui' ,
      'react/lib/ReactTransitionGroup': 'var window.React.addons.TransitionGroup',
      'react/lib/ReactCSSTransitionGroup': 'var window.React.addons.CSSTransitionGroup',
    }
```
fie 打包时直接把 React 排除掉了，采用的是引入 script 的形式。这里我们要把最新的源码拷贝出来，并对 fie 的配置进行修改。

### 1# 解决
1. 在项目中新建目录，`/lib/production/` 和 `/lib/development/`
2. 进入 react 和 react-dom 的 cjs 目录下，分别将 `react.production.min.js` `react-dom.pruduction.min.js`，
`react.development.js` `react-dom.development.js` 拷贝到刚才创建的目录下。并将他们重命名为`react.js`和`react-dom.js`
3. 修改`fie.config.js`
```jsx{14,20}
module.exports = {
  toolkit: 'fie-toolkit-qnui',

  toolkitConfig: {
    port: 9001,
    open: false,
    openTarget: 'pages/root.html',
    liveload: true
  },

  tasks: {
    start: [
      {
        command: 'NODE_ENV=development node build.js' 
        // 忽略提示信息，可以在此指定 NODE_ENV=production
      }
    ],
    build: [
      {
        command: 'NODE_ENV=production node build.js'
      }
    ],
    deploy: [
      {
        command: 'node deploy.js'
      }
    ],
    publish: []
  }
};
```
::: warning 提示
这里区分 **开发环境** 和 **生产环境**，目的是在开发环境构建中显示完整的 **语法检查** 和 **性能提示**。

若不需要，可将 start 和 build 全部指定 NODE_ENV=production
:::



4. 修改 `build.js`
```jsx{12}
let fs = require('fs-extra');
let globby = require('globby');
let path = require('path');

globby([
  'node_modules/babel-polyfill/dist/*',
  'node_modules/react-redux/dist/*',
  'node_modules/react-router/umd/*',
  'node_modules/react-router-redux/dist/*',
  'node_modules/redux-thunk/dist/*',
  'node_modules/redux/dist/*',
  `lib/${process.env.NODE_ENV}/*`, 
]).then(paths => {
  fs.mkdirsSync('build/lib/');
  paths.forEach((item) => {
    let filename = path.basename(item);
    fs.copySync(item, 'build/lib/' + filename);
  });
});
//使用统计

console.log('copy files to build/lib done ! mode:'+ process.env.NODE_ENV);
```
5. 修改`pages/js/root.js`

这个文件是 fie 对各种外置 script 进行加载的过程，上一步我们修改了要引入的 script 文件后，要在这里进行适配。

我们可以看到加载顺序为 :

`polyfill` => `react-with-addons` => `react-dom` => `redux` => `... ...`

这里的 react-with-addons 就是 React 15.6 和 React-addons 的合体。

我们将其路径修改为`../build/lib/react.js`,将 react-dom 路径修改为`../build/lib/react-dom.js`

到这里，第一步脚手架的修改工作就完成了！（但好像事情没有这么简单😂）

ok，执行 `fie start`，打开我们熟悉的界面，发现一片空白。于是乎 F12 打开控制台，果不其然一片报错。
其中最显眼的两个:
- `Cannot read property 'string' of undefined`
- `Cannot read property 'createClass' of undefined`
- `Cannot read property 'ReactTransitionGroup' of undefined`

打开堆栈信息一看，全都是年迈的 QNUI 报的错。
### 2# 坑
React16 去除掉了`PropTypes` `createClass` 以及 `ReactTransitionGroup`，取而代之的是`prop-types` `create-react-class` 和 `react-transition-group`第三方库。

而年久失修的QNUI，在使用`react.PropTypes.string`以及`react.createClass`时，就会出错了。

### 2# 解决

本来笔者的想法是对 React 库进行修改，把删掉的三个API添加进去。想了想实在是太麻烦，对源码动刀可是一不小心就要GG的。

最后使用了一个巧妙地方式，之前在修改`pages/js/root.js`时，引入了 `react-with-addons`。其中就包含了react 15。而我们需要的三个API，这不是得来全不费功夫嘛。

接着修改`root.js`，分三步走：
- 先引用`react-with-addons`，将三个API抽出来。
- 然后引用`react16`，覆盖掉`react15`。
- 将抽出来的三个API添加到 react16 中。（不知道会引发什么未知的问题，答案是肯定的。这是后话）
```js{2,7,8,10,15,16,17}
polyfill.onload = function () {
  reactWith.setAttribute('src', '../build/lib/react-with-addons.min.js?qntag=1');
  reactWith.setAttribute('type', 'text/javascript');
  reactWith.setAttribute('crossorigin', '');
  document.getElementsByTagName('head')[0].appendChild(reactWith);
  reactWith.onload = function () {
    const {PropTypes, createClass,addons} = window.React
    window.React = null;
     var react = document.createElement('script');
     react.setAttribute('src', '../build/lib/react.js?qntag=1');
     react.setAttribute('type', 'text/javascript');
     react.setAttribute('crossorigin', '');
     document.getElementsByTagName('head')[0].appendChild(react);
     react.onload = function () {
        window.React.PropTypes = PropTypes;
        window.React.createClass = createClass;
        window.React.addons = addons;
        // ... ...
     }
  }
}
```

ok，天衣无缝！

运行还是白屏。继续观察控制台，发现这么一个错误信息：

`Cannot read property 'addNodeForSafeClick' of null`


### 3# 坑
还是QNUI报错。查看源码我们发现，错误来自 Overlay 模态框 组件。
```jsx harmony
// ... ...
this.overlay = e['default'].unstable_renderSubtreeIntoContainer
      (this, overlay, this._wrap);
// ... ...

this.overlay.addNodeForSafeClick(node)
//... ...
```
它使用了这么一个 API `ReactDom.unstable_renderSubtreeIntoContainer`

这个 API 的作用是将元素渲染到父组件之外的DOM,用来做弹窗效果再适合不过。但他毕竟是有前缀`unstable`的，肯定在某些情况下会有问题。

在 react15 中，调用这个方法会直接返回被渲染元素的实例，而 react16 则会返回`null`。

所以这里会有`Cannot read property 'addNodeForSafeClick' of null`这个错误出现。

### 3# 解决

React16新增了[`Portals`](https://zh-hans.reactjs.org/docs/portals.html)来更好的实现该功能。

开始是想直接替换掉API，但后来发现两个API虽然功能相同，但是使用起来却大相径庭。

如果用`Portals`改写整个组件，风险和工作量还是很大。因为整个QNUI关于浮层的组件都是基于这个`Overlay`。

没办法只能继续分析源码，看一下为啥现在返回是 null 。

分析源码发现该API允许接收一个回调函数，回调函数绑定的`this`为被渲染元素实例。而触发回调时使用了一个`flushSyncCallbackQueueImpl`的内部API，意思也就是将所有回调放在微任务队列里统一执行。

大体上理解就是是旧版同步渲染元素，渲染完成后函数返回组件实例，而现在改为了异步渲染，需要在回调里获取实例。

这样一来思路就清晰了，我们在所有`unstable_renderSubtreeIntoContainer`的地方加入回调，在回调中处理实例绑定，而在所有使用到该实例的地方将其加入宏任务队列延迟调用，问题迎刃而解。

大概像这样：
```jsx harmony
// ... ...
var self4 = this;
 e['default'].unstable_renderSubtreeIntoContainer
      (this, overlay, this._wrap,function(){
        self4.overlay = this;
      });
// ... ...
setTimeout(()=>{
  this.overlay.addNodeForSafeClick(node)
})
//... ...
```

处理完这一问题后，将我们 hack 后的包放在`lib/production/`下，用它替换qnui

`qnui.setAttribute('src', '//g.alicdn.com/qn/QNUI-OPEN/0.6.1/qnui.min.js?qntag=1');`

替换为

 `qnui.setAttribute('src', '../build/lib/qnui.js?qntag=1');`
 


再次刷新页面，这次因该不会有啥问题了把。。。

### 4# 坑

我靠，这次出了一个摸不着头脑的问题
```jsx harmony
Uncaught Error: Element ref was specified as a string (.$.$onsale) but no owner was set. This could happen for one of the following reasons:
1. You may be adding a ref to a function component
2. You may be adding a ref to a component that was not created inside a component's render method
3. You have multiple copies of React loaded
```
### 4# 解决

这个问题看描述大概是使用了不同的react版本导致的。解决方法笔者也是误打误撞，将`react.addons.TransitionGroup`替换为了第三方库`react-transition-group`就好了。

修改方式：
1. 还是`root.js`
在 script 引用中加入`react-transition-group`,同时不在将`addons`添加到react16 上
```jsx{2,11,16,17}
reactWith.onload = function () {
  const {PropTypes, createClass} = window.React
  window.React = null;
  var react = document.createElement('script');
  react.setAttribute('src', '../build/lib/react.js?qntag=1');
  react.setAttribute('type', 'text/javascript');
  react.setAttribute('crossorigin', '');
  document.getElementsByTagName('head')[0].appendChild(react);
  react.onload = function () {
    var addons = document.createElement('script');
    addons.setAttribute('src', '../build/lib/react-transition-group.min.js?qntag=1');
    addons.setAttribute('type', 'text/javascript');
    addons.setAttribute('crossorigin', '');
    document.getElementsByTagName('head')[0].appendChild(addons);
    addons.onload = function () {
      window.React.PropTypes = PropTypes;
      window.React.createClass = createClass;
      var reactDom = document.createElement('script');
      reactDom.setAttribute('src', '../build/lib/react-dom.js?qntag=1');
      reactDom.setAttribute('type', 'text/javascript');
      reactDom.setAttribute('crossorigin', '');
      document.getElementsByTagName('head')[0].appendChild(reactDom);
    }
  }
}
```
2. 修改 `qn.js`
第一行的位置
```js
e.qnui = t(e.React, e.ReactDOM, e.React.addons.TransitionGroup)
```
修改为
```js
e.qnui = t(e.React, e.ReactDOM, e.ReactTransitionGroup.TransitionGroup)
```

这里的 e 为全局 window 对象，我们引入`react-transition-group`后，会自动为 window 注入 `ReactTransitionGroup`


### 5# 坑
测试过程中发现这样一个报错
```js
Cannot read property 'getContentNode' of null
```

还是 `Overlay` 的问题。这个错误不是必现的。出现这个错误须符合以下条件
- 页面出现浮层也就是Overlay
- Overlay 的点击事件直接跳转到新页面
- 在新页面上点击就会报错


### 5# 解决

具体的源码就不贴了，这里分析一下大体原因：

Overlay的点击事件是通过 `document.addEventlistener` 绑定的。也就是说：

弹层出现后，qnui 为 document 增加 click 监听，当用户点击时，判断目标元素是否为 Overlay。如果是，那么执行点击回调，如果不是，将其隐藏。

当我们路由跳转到新页面后，弹层直接被卸载,而监听没有去除。这样在新页面点击时触发监听导致报错。

源码在 componentWillUnmount 生命周期中有去除监听的操作，但这个地方直接跳转页面会导致代码执行被打断。

一开始想到解决方式是为跳转增加延迟，但考虑到用户体验以及稳定性，决定对组件源码做一下兼容。

- 调用之前判断组件是否已卸载，如果已卸载，停止调用并手动去除监听。



## 完成
打开浏览器刷新页面，看着久违的页面浮现在我们眼前，真的是留下了激动地口水。

`React 16`我们可以为所欲为！

## 附
### `root.js`
```js
// 根据QueryString参数名称获取值
function getQueryStringByName(name) {
  var result = location.search.match(new RegExp(`[\?\&]${name}=([^\&]+)`, 'i'));
  if (result == null || result.length < 1) {
    return '';
  }
  return result[1];
}

window.onload = function () {
  var version = "";
  //var version = "-2019072301"; //打包之后的版本号

  var event = decodeURI(getQueryStringByName('event'));

  var numiid = decodeURI(getQueryStringByName('iid')); // 商品详情
  var itemStatus = decodeURI(getQueryStringByName('itemStatus')); // 商品列表
  if (event) {
    if (event == 'event_itemList' || event == 'itemList') {
      if (itemStatus != null && itemStatus != '') {
        if (itemStatus == 'hasshowcase') { // 橱窗推荐--九宫格
          window.location.href = `${window.location.href.split('?')[0]}#/itemManage/itemList/${itemStatus}`;
        } else {
          window.location.href = `${window.location.href.split('?')[0]}#/itemManage/itemList`;
        }
      }
    } else if (event == 'event_itemDetail' || event == 'itemDetail') { // /商品明细 新加参数itemDetail
      // window.location.href = "../pc/web/root.html?event=itemEdit&num_iid=" + numiid;
      window.location.href = `${window.location.href.split('?')[0]}#/itemManage/itemDetail/${numiid}`;
    } else if (event == 'customEvent') { // /进入商品插件    或指定功能
      var itemStatus = decodeURI(getQueryStringByName('itemStatus')); // 类型

      if (itemStatus != null && itemStatus != undefined && itemStatus != '') {
        if (itemStatus == 'itemList') { // 商品管理
          window.location.href = `${window.location.href.split('?')[0]}#/itemManage/itemList`;
        } else if (itemStatus == 'waterMark') { // 主图水印
          window.location.href = `${window.location.href.split('?')[0]}#/templet/waterMark`;
        } else if (itemStatus == 'mobileDetail') { // 手机详情
          window.location.href = `${window.location.href.split('?')[0]}#/mobileDetail`;
        } else if (itemStatus == 'smartList') { // 智能上下架
          window.location.href = `${window.location.href.split('?')[0]}#/flowUp/smartList`;
        } else if (itemStatus == 'smartWindow') { // 智能橱窗
          window.location.href = `${window.location.href.split('?')[0]}#/flowUp/smartWindow`;
        } else if (itemStatus == 'titleOptimize') { // 标题优化
          window.location.href = `${window.location.href.split('?')[0]}#/flowUp/titleOptimize/itemList/aa`;
        } else if (itemStatus == 'activeCenter') { // 活动中心
          window.location.href = `${window.location.href.split('?')[0]}#/more/activeCenter`;
        } else if (itemStatus == 'itemList') { // 优化宝贝
          window.location.href = `${window.location.href.split('?')[0]}#/itemManage/itemList`;
        } else if (itemStatus == 'editItem') { // 编辑宝贝
          var numIid = decodeURI(getQueryStringByName('numIid')); // 商品编号
          window.location.href = `${window.location.href.split('?')[0]}#/itemManage/itemDetail/${numIid}`;
        }
      }
    } else {
      window.location.href = `${window.location.href.split('?')[0]}#/`;
    }
  } else {
    window.location.href = `${window.location.href.split('?')[0]}#/`;
  }

  var qncss = document.createElement('link');
  qncss.setAttribute('href', '//g.alicdn.com/qn/QNUI-OPEN/0.6.1/qnui.min.css?qntag=1');
  qncss.setAttribute('rel', 'stylesheet');
  qncss.setAttribute('type', 'text/css');
  document.getElementsByTagName('head')[0].appendChild(qncss);

  var css = document.createElement('link');
  css.setAttribute('href', `../build/pages/root/index${version}.css`); // 注意版本号
  css.setAttribute('rel', 'stylesheet');
  css.setAttribute('type', 'text/css');
  document.getElementsByTagName('head')[0].appendChild(css);

  var polyfill = document.createElement('script');
  polyfill.setAttribute('src', '../build/lib/polyfill.min.js?qntag=1');
  polyfill.setAttribute('type', 'text/javascript');
  polyfill.setAttribute('crossorigin', '');
  document.getElementsByTagName('head')[0].appendChild(polyfill);
  polyfill.onload = function () {
    var reactWith = document.createElement('script');
    reactWith.setAttribute('src', '../build/lib/react-with-addons.min.js?qntag=1');
    reactWith.setAttribute('type', 'text/javascript');
    reactWith.setAttribute('crossorigin', '');
    document.getElementsByTagName('head')[0].appendChild(reactWith);
    reactWith.onload = function () {
      const {PropTypes, createClass} = window.React
      window.React = null;
      var react = document.createElement('script');
      react.setAttribute('src', '../build/lib/react.js?qntag=1');
      react.setAttribute('type', 'text/javascript');
      react.setAttribute('crossorigin', '');
      document.getElementsByTagName('head')[0].appendChild(react);
      react.onload = function () {
        var addons = document.createElement('script');
        addons.setAttribute('src', '../build/lib/react-transition-group.min.js?qntag=1');
        addons.setAttribute('type', 'text/javascript');
        addons.setAttribute('crossorigin', '');
        document.getElementsByTagName('head')[0].appendChild(addons);
        addons.onload = function () {
          window.React.PropTypes = PropTypes;
          window.React.createClass = createClass;
          var reactDom = document.createElement('script');
          reactDom.setAttribute('src', '../build/lib/react-dom.js?qntag=1');
          reactDom.setAttribute('type', 'text/javascript');
          reactDom.setAttribute('crossorigin', '');
          document.getElementsByTagName('head')[0].appendChild(reactDom);
          reactDom.onload = function () {
            var redux = document.createElement('script');
            redux.setAttribute('src', '../build/lib/redux.min.js?qntag=1');
            redux.setAttribute('type', 'text/javascript');
            redux.setAttribute('crossorigin', '');
            document.getElementsByTagName('head')[0].appendChild(redux);
            redux.onload = function () {
              var reactRedux = document.createElement('script');
              reactRedux.setAttribute('src', '../build/lib/react-redux.min.js?qntag=1');
              reactRedux.setAttribute('type', 'text/javascript');
              reactRedux.setAttribute('crossorigin', '');
              document.getElementsByTagName('head')[0].appendChild(reactRedux);
              reactRedux.onload = function () {
                var reactRouter = document.createElement('script');
                reactRouter.setAttribute('src', '../build/lib/ReactRouter.min.js?qntag=1');
                reactRouter.setAttribute('type', 'text/javascript');
                reactRouter.setAttribute('crossorigin', '');
                document.getElementsByTagName('head')[0].appendChild(reactRouter);
                reactRouter.onload = function () {
                  var reactRouterRedux = document.createElement('script');
                  reactRouterRedux.setAttribute('src', '../build/lib/ReactRouterRedux.min.js?qntag=1');
                  reactRouterRedux.setAttribute('type', 'text/javascript');
                  reactRouterRedux.setAttribute('crossorigin', '');
                  document.getElementsByTagName('head')[0].appendChild(reactRouterRedux);
                  reactRouterRedux.onload = function () {
                    var thunk = document.createElement('script');
                    thunk.setAttribute('src', '../build/lib/redux-thunk.min.js?qntag=1');
                    thunk.setAttribute('type', 'text/javascript');
                    thunk.setAttribute('crossorigin', '');
                    document.getElementsByTagName('head')[0].appendChild(thunk);
                    thunk.onload = function () {
                      var qnui = document.createElement('script');
                      qnui.setAttribute('src', '../build/lib/qnui.js?qntag=1');
                      qnui.setAttribute('type', 'text/javascript');
                      qnui.setAttribute('crossorigin', '');
                      document.getElementsByTagName('head')[0].appendChild(qnui);
                      qnui.onload = function () {
                        var vendor = document.createElement('script');
                        vendor.setAttribute('src', `../build/vendor${version}.js`); // 注意版本号
                        vendor.setAttribute('type', 'text/javascript');
                        vendor.setAttribute('crossorigin', '');
                        document.getElementsByTagName('head')[0].appendChild(vendor);
                        vendor.onload = function () {
                          var itemManagement = document.createElement('script');
                          itemManagement.setAttribute('src', `../build/pages/root/index${version}.js`); // 注意版本号
                          itemManagement.setAttribute('type', 'text/javascript');
                          itemManagement.setAttribute('crossorigin', '');
                          document.getElementsByTagName('head')[0].appendChild(itemManagement);
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
```
### build.js
```js
'use strict';

let fs = require('fs-extra');
let globby = require('globby');
let path = require('path');
//STEP 3 将lib copy 到 build 目录

globby([
  'node_modules/babel-polyfill/dist/*',
  'node_modules/react-redux/dist/*',
  'node_modules/react-router/umd/*',
  'node_modules/react-router-redux/dist/*',
  'node_modules/redux-thunk/dist/*',
  'node_modules/redux/dist/*',
  'lib/common/*',
  `lib/${process.env.NODE_ENV}/*`,
]).then(paths => {
  fs.mkdirsSync('build/lib/');
  paths.forEach((item) => {
    let filename = path.basename(item);
    fs.copySync(item, 'build/lib/' + filename);
  });
});
//使用统计

console.log('copy files to build/lib done ! mode:'+process.env.NODE_ENV);

```

### fie.config.js
```js
/**
 * 套件帮助文档 可查看: http://gitlab.alibaba-inc.com/fie/fie-toolkit-qnui
 */
module.exports = {
  // 当前项目使用的fie套件
  toolkit: 'fie-toolkit-qnui',

  toolkitConfig: {
    // 本地服务器端口号,为与交易共存，设置9001
    port: 9001,
    // 是否自动打开浏览器
    open: false,
    // 打开浏览器后 自动打开的 目标页面
    openTarget: 'pages/root.html',
    // 文件修改后是否自动刷新浏览器
    liveload: true
  },

  tasks: {
    start: [
      {
        // 执行build目录的copy
        command: 'NODE_ENV=development node build.js '
      }
    ],
    build: [
      {
        // 同步类库到build/lib目录
       command: 'NODE_ENV=production node build.js'
      }
    ],
    deploy: [
      {
        //同步到tomcat服务器
        command: 'node deploy.js'
      }
    ],
    publish: []
  }
};
```
### lib
```
lib
|- common
   |- react-transition-group.min.js
   |- react-with-addons.min.js
|- development
   |- qnui.js
   |- react.js
   |- react-dom.js
|- production
   |- qnui.js
   |- react.js
   |- react-dom.js
```
其中`qn.js`是经过上述所有`hack`之后的

[文件地址](https://github.com/7revor/fie-react-update-lib)
