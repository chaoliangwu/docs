## 现状
上文讲过了动态弹窗组件，我们可以灵活的控制弹窗交互，减少代码耦合。但是有这么一种**特例**。

### 特例
如果弹窗组件中含有输入框，在IOS平台下，当输入框呼起键盘时，会自动调整弹窗高度不会出现遮挡。
而在安卓系统中，系统不会对遮挡情况进行处理，此时我们就需要根据键盘事件自己来调整组件位置。

## 原理

- 将键盘事件进行全局管理，为所有需要自适应的组件分发键盘高度。
- 利用React的特性，将键盘高度放在各组件`state`中进行管理，当高度改变时，组件重新渲染。

## 实现

### 组件注册
```jsx harmony
import QN from 'QAP-SDK'
let componentMap = {},// 组件集合
  keyBoardHeight=0 //初始键盘高度
  
export function register(component){
  if(component.name&&component.instance){
    componentMap[component.name]=component.instance
  }
  return keyBoardHeight
}
```
- 将组件实例注册到全局变量`componentMap`并返回当前键盘高度

### 监听事件
```jsx harmony
  /**
   * 事件监听
   */
  if(!QN.os.ios){
    QN.on('Global.KeyboardWillShow', ({height}) => {
      keyBoardHeight=height
      setState()
    })
    QN.on('Global.KeyboardWillHide', () => {
      keyBoardHeight=0
      setState()
    })
  }
```
- `Global.KeyboardWillShow`事件接受一个参数，值为键盘高度
- 在安卓机的键盘显示和关闭时，将新的`keyBoardheight`分发给组件

### 状态分发
```jsx harmony
function setState() {
    for (let v of Object.values(componentMap)) {
        v.setState({
          keyBoardHeight: keyBoardHeight
        })
    }
}
```
- 遍历`componentMap`，调用组件实例的`setState()`来重新渲染组件
### 组件注销
```jsx harmony
export function logout(component){
  if(componentMap[component.name]){
    delete componentMap[component.name]
  }
}
```
- 组件销毁后，注销组件

## 调用方式
### 引入方法
```jsx harmony
import {logout, register} from "$util/heightProvider";
```
### `constructor`
```jsx harmony
constructor(props) {
    super(props);
    MyComponent.instance = this;
    let keyBoardHeight = register(MyComponent)
    this.state = {
      keyBoardHeight: keyBoardHeight
    }
  }
```
- 通过`register`注册组件实例并得到一个当前键盘高度存入`state`

### `render`
```jsx harmony
render() {
  const height = window.screen.height - this.state.keyBoardHeight
  return(
    <View style={{height:height}}>
    /////
    </View>
  )
}
```
- 在`heightProvider`中已经将`MyConponent`实例注册，所以在键盘高度发生变化时，会自动为所有注册过的组件`setState`重新渲染

### 组件注销
```jsx harmony
    logout(MyConponent)
    unmountComponentAtNode(MyConponent.dom);
    document.body.removeChild(MyConponent.dom);
```
