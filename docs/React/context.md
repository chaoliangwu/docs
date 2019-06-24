## 介绍
应IOS审核要求，应用内部不允许绕过AppStore进行内购，所以需要对IOS免费版的高级功能进行隐藏，而高级版和安卓则不受影响。
## 思路
移动端是多页面应用，无法使用`redux`进行全局数据管理，结合到之前封装的高阶组件[`titleWrapper`](/docs/React/titleWrapper.html)，在这里使用`react-context`进行伪`store`处理。

- `titleWrapper`为每个页面注入相同的`context`
- 在需要调用的页面或者子组件内直接通过`this.context`获取。

<Picture src="context2.jpg"/>

## 什么是 Context
在一个典型的 `React` 应用中，数据是通过 `props` 属性自上而下（由父及子）进行传递的，
但这种做法对于某些类型的属性而言是极其繁琐的（例如：地区偏好，UI 主题），这些属性是应用程序中许多组件都需要的。
`Context` 提供了一种在组件之间共享此类值的方式，而不必显式地通过组件树的逐层传递 `props`。
### 兼容
由于`rax`中的`React`版本较老，不支持新的`Context API`,所以这里我们使用旧`API`。
#### 新版`API`
- 创建`context`对象
```jsx
//定义一个颜色的默认值
const defaultColor = "#000";
const ColorContext = React.createContext(defaultColor);
```
- 使用`Provider`生成`context`
```jsx harmony
class Parent extends React.Component {
    state = {
        childColor: "#000"
    }

    render(){
     return (
         <ColorContext.Provider value={this.state.childColor}>
                <Child/>
            </ColorContext.Provider>
        )
    }    
}
``` 
- 使用`Consumer`组件获取`context`
```jsx
class Child extends React.Component {
    render(){
     return (
         <ColorContext.Consumer>
            {(value)=>(
               <span style={{color: value}}>context颜色</span>
            )}
         </ColorContext.Consumer>
        )
    }    
}
```
#### 旧版`API`
- 父组件定义
```jsx{2,3,4}
class Parent extends React.Component {
  static childContextTypes{
    color: PropTypes.string
  }
  getChildContext() {
    return {
      color: "red"
    };
  }
}
```
- 子组件引用
```jsx{2,3,4,8}
class Child extends React.Component {
  static contextTypes{
    color: PropTypes.string
  }
  render() {
    return (
      <p>
        {this.context.color}
      </p>
    );
  }
}
```
## 具体实现

### titleWrapper
```jsx harmony
const iosLimit = QN.os.ios&&true; // 默认打开
function _titleWrapper(title, param) {
  return function doTitle(WrappedComponent) {
    return class extends PureComponent {
      static childContextTypes = { // 定义Context 全局上下文
        iosLimit: PropTypes.bool, // ios高级功能控制,全部版本
        iosFreeLimit: PropTypes.bool // ios高级功能控制,免费版,只有在iosLimit为true时，才限制免费版功能，否则该项始终为false
      }
      
      constructor(props) {
        super(props);
        this.state={
          iosFreeLimit: iosLimit,
          iosLimit
        };
      }

      getChildContext() { // 返回Context对象，方法名是约定好的
        return {
          iosLimit:this.state.iosLimit,
          iosFreeLimit: this.state.iosFreeLimit
        };
      }

      componentDidMount() {
        const self = this;
        const p1 = getLimit(); // 获取接口数据，判断是否限制
        const p2 = vipGet();
        Promise.all([p1, p2]).then(results=>{
          const result = results[1];
          const limitInfo = results[0];
          self.setState({
            iosLimit:QN.os.ios&&limitInfo.value==1, // value == 1 ,为IOS所有版本限制高级功能
            iosFreeLimit: QN.os.ios&&limitInfo.value==1&&!result.isVip // IOS限制的前提下，只对免费版限制的功能
          });
        });
      }

      render() { // 渲染传入的子组件，即页面
        return (<WrappedComponent {...param} {...this.props} />);
      }
    };
  };
}
export default function titleWrapper(title, component) {
  const Page = _titleWrapper(title, param)(component);
  render(<Page/>);
}
```
### 需要控制的子组件
封装好的按钮组件，在使用时，如果该按钮功能受IOS高级功能限制，那么为该组件传入属性`iosFreeLimit=true`，然后在组件内部通过组件`props`和`context`两个条件进行判断

#### 调用
```html
    <PyButton title='我是被限制的高级功能' iosLimit />
    <PyButton title='我是免费功能 '/>
```
#### 组件实现
```jsx harmony
class PyButton extends Component {
  static contextTypes = { // 接收titleWrapper注入的context
    iosFreeLimit: PropTypes.bool
  }
  render(){
    if(this.props.iosFreeLimit&&this.context.iosFreeLimit){
      return null
    }else{
      /* 渲染组件内容 */
    }
  }
  
}
```
