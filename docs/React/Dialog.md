## Demo

<Picture src="dialog.jpg" name="组件弹出" width = "300"/>

## 介绍
最近在进行一个基于Weex的手机端项目，用了阿里的Rax组件，由于资源太少，市面上常见的组件都无法方便快捷的实现弹窗，所以自己从零开始研究了一个。

一开始为了满足业务需要，简单的写了一个Dialog，但是这个Dialog的取消的确定事件都要以参数的性质传入这就导致使用不便，
由ElementUI受到启发,于是想基`Promise`实现一个方便好用的组件
 
 由于刚刚开始学习，一些实现方式也是我自己琢磨出来的，如果有逻辑错误或者可以优化的地方欢迎提点指正。

## ElementUI中的弹窗组件

```jsx harmony
this.$confirm('此操作将永久删除该文件, 是否继续?', '提示', {
          confirmButtonText: '确定',
          cancelButtonText: '取消',
          type: 'warning'
        }).then(() => {
          this.$message({
            type: 'success',
            message: '删除成功!'
          });
        }).catch(() => {
          this.$message({
            type: 'info',
            message: '已取消删除'
          }); 
```

#### 分析
原理是调用静态方法，然后在方法中控制窗口的显示，该方法返回一个Promise对象，大致思路为

```jsx harmony
let myPromise;
 open=()=>{
        return new Promise((resolve, reject) => {
            myPromise={resolve,reject}//此处把promise的resolve和reject方法存到变量中，
                                      //这样就可以在点击确定或者取消的时候对promise做相应的处理
        })
    }
```
```jsx harmony
confirm=()=>{
    myPromise.resolve()
}
cancel=()=>{
    myPromise.reject()
}
```
这样一来，在父界面调用的时候逻辑清晰明了：
```jsx harmony
 myDialog.open(message).then(()=>{
                    //此处处理确认逻辑
                }).catch(()=>{
                  //此处处理取消逻辑
                })
```
开始在项目中采取的方式是在每一个需要调用dialog组件的地方，手动把dialog插入到body的最底部
```jsx harmony
import MyDialog from "../../components/dialog/MyDialog";

//······
//······
render()
{
return
    <View>
        //······
        //······

        <MyDialog/>
    </View>
}
```
毋庸置疑，上述方式耦合性将会非常高，在每一个需要调用的页面都要引入这个组件，看了看React的文档，研究出来一种目前我认为还可以的方式，那就是使用ReactDOM的 render方法来自动控制组件的渲染。

## 实现

```jsx harmony
import {createElement, Component, render, PureComponent, findDOMNode, unmountComponentAtNode} from 'rax';
import {View, Text, Dialog, Touchable} from 'nuke';

let _self;
let myPromise;
let div;

export default class Dialog extends Component {
    static confirm(info) {
        div = document.createElement('div')
        document.body.appendChild(div)
        render('<PyDialog />',div)
        _self.setState({
            type: `confirm`,
            info: info
        })

        return new Promise((resolve, reject) => {
            myPromise = {resolve, reject}
        })
    }

    constructor() {
        super();
        _this = this;
    }

    destory() {
        unmountComponentAtNode(div)
        document.body.removeChild(div)//组件销毁
    }

    resolve() {
        myPromise.resolve();
        this.destory()
    }

    reject() {
        myPromise.reject()
        this.destory()
    }

    render() {
        return

        <View>
            <View>
                {this.state.info}
            </View>
            <View style={myStyle.bottomBox}>
                <Touchable onPress={this.reject}>
                    <Text style={myStyle.btnGray}>取消</Text>
                </Touchable>
                <Touchable onPress={this.resolve}>
                    <Text style={myStyle.btnRed}>确认</Text>
                </Touchable>
            </View>
        </View>

    }
}
```

## 调用
```jsx harmony
import Dialog from './Dialog'

PyDialog.confirm(`确定要删除吗？`).then(()=>{
                    this.delete()
                }).catch((data)=>{
                    
                })
```
