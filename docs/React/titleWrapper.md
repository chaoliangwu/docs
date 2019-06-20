---
title: titleWrapper
date: 2019-03-19 16:01:11
categories: React
---
## 作用
自动封装参数以及设置标题
## 背景
在qap平台中，使用QN.navigator来跳转
```javascript
QN.navigator.push({
      url: url,
      title: '标题',
      query: {name:'7revor'},
    });
```

## 缺点
- 传递的页面title只有在第一次进去的时候会显示，刷新页面后就会丢失title。
- 使用这个导航进入新页面后，页面传递参数需要手动获取
```javascript
import {Util} from 'nuke';
let url = Util.Location.search;
let param = QN.uri.parseQueryString(url);
```

## 思考
基于此种不方便的特性以及React高阶组件，简单实现了一个自动封装参数以及title的HOC

### 具体实现
```jsx
import {createElement, PureComponent, render} from 'rax';
import {Util} from 'nuke'
import QN from 'QAP-SDK'

/**
 * 给组件包装一层title,将QAP页面传过来的参数封装到组件的props中
 * @param title：页面标题（刷新不丢失）
 * @param component  组件原型
 */
export default function titleWrapper(title, component) {
//解析页面参数
  const param = QN.uri.parseQueryString(Util.Location.search.replace("?", ""))
//组件封装
  const Ele = _titleWrapper(title, param)(component)
  render(<Ele/>)
}

function _titleWrapper(title, param) {
  return function doTitle(WrappedComponent) {
    return class extends PureComponent {
      componentDidMount() {
        //每一次渲染页面时，都重新设置标题，防止标题丢失
        QN.navigator.setTitle({
          query: {
            title: title
          }
        });
      }
      render() { 
      //封装上一个方法得到的param到组件的props中
        return (<WrappedComponent {...param} {...this.props}/>)
      }
    }
  }
}
```

### 调用

原本的React页面实现:
```javascript
render(<MyComponent/>);
```
使用HOC之后：
```javascript
import {titleWrapper} from Util
titleWrapper('我是标题', MyComponent)
```
这样一来，就可以在组件生命周期里使用 this.props来获取qap页面参数。
