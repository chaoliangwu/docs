## 现状
QAP安卓端在弹出键盘时，我们点击键盘上的完成按钮，键盘会自动收起。如果输入完成后未点击完成按钮，直接点击保存等相关操作，那么呼出的这个键盘就会一直保留在界面上。
我们现有的解决方式是给Input组件添加ref属性
```jsx harmony
<Input ref='textInput'/>
```
然后再保存或者其他操作中，手动让输入框失去焦点来关闭键盘
```jsx harmony
save(){
  this.refs. textInput.blur()
}
```
## 缺点
这种处理方式在界面中输入框较少时比较好用。但如果这个输入框是动态生成的（追加don节点的方式，无法为动态生成的组件标记ref），又或者界面中有十几个Input组件，那就行不通了。
这时候可以采取此种解决方式：

## 优化
首先，在需要调用Input的页面（可以是弹窗），对Input做处理：
```jsx harmony
import {Input} from 'nuke'
class MyPage extends Component{
  constructor(props){
  super(props)
  //对input的原型进行代理，让所有的input实例获得焦点时都触发此方法
  Input.prototype.focusHandler = new Proxy(Input.prototype.focusHandler, {
    apply (target, ctx, args) { 
      Input.currentTarget = ctx; //为Input类添加缓存，即当前被激活的Input实例
        return Reflect.apply(target, ctx, args);
      }
  })
  }
}
}
```

`apply` 方法可以接受三个参数
- `target` 目标对象
- `ctx` 目标对象的上下文对象 `this`
- `args` 目标对象的参数数组

这样一来，我们在保存方法中就可以直接
```jsx harmony
  Input.currentTarget&&Input.currentTarget.blur()
```
这样就可以实现关闭键盘的功能，界面中再多的输入框也不怕了。

### 注意点：
如果你的页面是弹窗等组件，在保存后需要执行组件销毁，这里要注意blur方法是一个异步方法，由于js是单线程，这个方法不会立即执行，而是会被放入任务队列，在你的当前代码执行完毕（也就是所有的同步代码执行完毕）后才会调用。这样一来，销毁组件就会发生在你的blur事件之前，那么blur也就不会生效了。
解决方式利用setTimeout，由于setTimeout中的方法也不会立即执行，而是在计时器结束后被放入任务队列，那么我们的blur代码在任务队列中的执行顺序就会在组件销毁之前了
```jsx harmony
Input.currenttarget.blur()
//处理代码逻辑
setTimeout(()=>{
  this.destory()//销毁组件
},100)
```
这样一来，`blur()`方法就可以正常执行了
