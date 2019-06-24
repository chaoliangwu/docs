## 介绍

最近用到一个动作菜单，由于nuke自带的样式不符合项目的统一样式规范，所以自己抽了一个出来，关键代码是动态向body插入子元素以及transition效果的实现。选项过多超过一屏后显示滚动列表，高度响应qap安卓键盘呼出关闭。

<Picture src="actionsheet.jpg" name="组件弹出" width = "300"/>

## 调用示例

```jsx harmony
const data = {
    onSale:'出售中',
    inventory:'仓库中',
    all:'全部'
}
ActionSheet.select(data).then(result=>{
      //result:{key:'onSale',value:'出售中'}
})
```

## 组件实现
```jsx
/**
 * Actionsheet
 * 下拉动作菜单
 * @author lxy
 */
import {createElement, PureComponent, render, unmountComponentAtNode} from 'rax';
import {View, Text, TouchableHighlight, Dimensions,ScrollView} from 'nuke';
import style from './style.less'
import QN from 'QAP-SDK'
import doTransition from "$util/PyTransition";

let {height, width} = Dimensions.get(`screen`)//获取屏幕宽高
let pureHeight = height / (width / 750) - 200 / (width / 750) //根据比例计算屏幕真实高度
let keyBoardHeight = 0 //键盘高度
if (!QN.os.ios) {
  QN.on('Global.KeyboardWillShow', ({height}) => {
    keyBoardHeight = height
    Actionsheet.updateHeight() //重新计算组件高度
  })
  QN.on('Global.KeyboardWillHide', () => {
    keyBoardHeight = 0
    Actionsheet.updateHeight()
  })
}

export default class Actionsheet extends PureComponent {
  /**
   *
   * @param data eg:{onSale:`出售中`,out:`已售完`}
   * @returns {Promise<any>}
   */
  static select(data) {
    if (!SelectDown.isExist) {
      Actionsheet.isExist = true;//单例模式，同一页面只允许存在一个实例
      Actionsheet.dom = document.createElement('div');//页面渲染节点
      document.body.appendChild(Actionsheet.dom);//将dom节点插入document
      render('<SelectDown data={data}/>', Actionsheet.dom);//渲染组件到dom节点中
      return new Promise((resolve, reject) => {
        Actionsheet.promise = {resolve, reject}//回调promise
      })
    }
  }

  componentDidMount() {
    const option = {
      timingFunction: 'ease-in-out',
      delay: 0,
      duration: 200
    }
    //初始化动画效果，遮罩层由透明变为0.5，body区域内容从最底部上滑
    doTransition(this.refs.side, {transform: `translateY(${-Actionsheet.bottom - 10})`}, option)//10 marginBottom
    doTransition(this.refs.mask, {backgroundColor: 'rgba(0,0,0,0.5)'})
  }
  constructor(props) {
    let {data} = props
    super(props);
    let map = new Map(Object.entries(data));
    this.state = {
      map,
      showSide: false,
      remainHeight:pureHeight-keyBoardHeight,
      allHeight:(map.size + 1) * 114 + 16,////计算组件高度，(数据长度+取消)*114+取消marginTop
    }
   Actionsheet.instance=this
    const {remainHeight,allHeight} = this.state
    Actionsheet.bottom = remainHeight>allHeight?allHeight:remainHeight
  }
  destroy() {
    unmountComponentAtNode(SelectDown.dom)//销毁react实例
    document.body.removeChild(SelectDown.dom)//移除dom节点
    Actionsheet.isExist = false//销毁组件
  }

  chooseItem({key, value}) {
    Actionsheet.promise.resolve({key, value})//处理选择事件
    this.destroy()
  }
//渲染选项列表
  renderBody = () => {
    let self = this;
    let list = []
    let i = 0;
    for (let [key, values] of this.state.map.entries()) {
      let ownStyle;
      if (i == 0) {//处理首尾选项边框
        ownStyle = styles.topBorder
      }
      if (i == this.state.map.size - 1) {
        ownStyle = styles.bottomBorder
      }
      list.push(
        <TouchableHighlight key={key} style={[style.content, ownStyle, i != 0 ? styles.border : '']}
                            onPress={this.chooseItem.bind(self, {key, value: values})}>
          <Text style={style.text}>
            {values}
          </Text>
        </TouchableHighlight>
      )
      i++;
    }
    const {remainHeight,allHeight} = this.state
    //屏幕剩余高度大于选项高度，显示选项实际高度，否则显示屏幕剩余高度
    const height = remainHeight>allHeight?allHeight:remainHeight
    return (
      <View ref="side" style={[style.bottom, {bottom: -Actionsheet.bottom,height:height}]}>
        <ScrollView style={style.list}>
          {list}
        </ScrollView>
        <TouchableHighlight style={style.cancle} onPress={this.destroy}>
          <Text style={style.textCancle}>取消</Text>
        </TouchableHighlight>
      </View>
    )
  }

  render() {
    return (
      <View ref='mask' onClick={this.destroy} style={[style.container, {height: height}]}>
        {this.renderBody()}
      </View>
    )
  }
}
Actionsheet.isExist = false
Actionsheet.updateHeight=function(){ //更新屏幕剩余高度
  Actionsheet.instance&& Actionsheet.instance.setState({
    remainHeight: pureHeight-keyBoardHeight
  })

}
const styles = {
  topBorder: {
    borderTopRightRadius: '10rem',
    borderTopLeftRadius: '10rem',
    height:'104rem'
  },
  bottomBorder: {
    borderBottomRightRadius: '10rem',
    borderBottomLeftRadius: '10rem',
    height:'104rem'
  },
  border: {
    borderTopWidth: '1rem',
    borderTopColor: '#DCDEE3'
  }
}
```

style.less
```jsx harmony
.container{
  width: 750rem;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  background-color: rgba(0,0,0,0);
  position: fixed;
  bottom: 0;
}
.bottom{
  width: 750rem;
  flex-direction: column;
  justify-content: flex-end;
  align-items: center;
  position: fixed;
}
.cancle{
  margin-top: 16rem;
  width: 710rem;
  justify-content: center;
  align-items: center;
  height: 114rem;
  background-color: #fff;
  border-radius: 10rem;
}
.content{
  width: 710rem;
  justify-content: center;
  align-items: center;
  height: 114rem;
  background-color: #fff;
}
.list{
  width: 710rem;
  background-color: #fff;
  border-radius: 10rem;
  justify-content: flex-start;
  align-items: center;
  padding-top: 10rem;
  padding-bottom: 10rem;
}
.text{
  font-family: MicrosoftYaHei;
  width: 710rem;
  font-size: 32rem;
  color: #333333;
  text-align: center;
}
.textCancle{
  font-family: MicrosoftYaHei;
  width: 710rem;
  font-size: 32rem;
  color: #F54531;
  text-align: center;
}
```



