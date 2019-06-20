## 介绍
适用于千牛移动端侧导航栏组件
## 效果图
<Picture src="tabbar.jpg" name="组件弹出" width = "300"/>

## 调用示例

### `View`
```jsx
<TabBar activeKey={this.state.activeKey}
onChange={this.tabChange.bind(this)}> //点击事件里要更改stata.activeKey来触发组件更新
  <TabBar.Item title={`页面1`} tabKey={'page1'}>
  //tab页1
  </TabBar.Item>
<TabBar.Item title={`页面2`} tabKey={'page2'}>
  //tab页2
</TabBar.Item>
</TabBar>

```
### `Controller`
```jsx harmony
tabChange({next: tabKey}){
  this.setState({activeKey: tabKey});
}
```



## 具体实现
```jsx harmony
export default class TabBar extends PureComponent {
  static Item = Item //子组件
  constructor(props) {
    super(props);
    //存储tab页id以及坐标，用于实现动画触发
    const map = new Map();
    props.children.forEach((child, index) => {
      //默认页面宽度为750，tabbar长度为80
      const length = 750 / props.children.length;
      const position = index * length + length / 2 - 42
      map.set(child.props.tabKey, position);
    })
    this.state = {
      map
    }
  }

  componentDidMount() {
    const left_new = this.state.map.get(this.props.activeKey)
    const dom = this.refs.border
    //初始动画渲染
    doTransition(dom, {transform: `translateX(${left_new + 80})`})
  }

  changeSelect(key) {//选择事件
    //获取点击tab页的坐标
    const left_new = this.state.map.get(key)
    const dom = this.refs.border
    //平移底部border
    doTransition(dom, {transform: `translateX(${left_new + 80})`}, null, () => {
    //回调
      this.props.onChange && this.props.onChange({next: key})
    })
  }

  getChild() {//获取子tab页
    //根据tab页id获取页面内容
    let child = this.props.children.find(child => {
    return child.props.tabKey == this.props.activeKey
  })



}
```
页面内容渲染
```jsx harmony
render(){
  let child = this.getChild()
  return (
    <View style={[style.container,
      this.props.full ? {flex: 1} : '',
      this.props.style ? this.props.style : '']}>
      <View style={style.borderContainer}>
        <View style={style.body}>
          //渲染导航
          {this.props.children.map(obj => {
            const flag = obj.props.tabKey == this.props.activeKey
            return (
              <TouchableHighlight 
                onPress={this.changeSelect.bind(this, obj.props.tabKey)} 
                style={style.tab}>
              <View style={{flex: 1}}/>//平分页面占比
              <View style={{flexDirection: "row"}}>
                <Text style={flag ?
                  style.tabTextFocus 
                  : 
                  style.tabText}>{obj.props.title}
                  </Text>
                {obj.props.nextTitle ? 
                  <Text style={obj.props.nextTitle === "(有)" ?
                  style.yesText 
                    : 
                    style.noText}>{obj.props.nextTitle}</Text> 
                  : null}
              </View>
              <View style={style.num}>
                <Text style={flag ?
                  style.numFocus : style.numText}>
                  {!obj.props.total || 
                  (obj.props.total == 0 && !this.props.showZero) ? 
                    '' :
                    obj.props.total > 9999 ? 
                      `(9999+)` : `(${obj.props.total})`}
                </Text>
              </View>
            </TouchableHighlight>)
          })}
        </View>
        //底部border
        <View style={style.bottom}>
          <View ref={`border`} style={[style.bottom_border]}/>
        </View>
      </View>
      //渲染根据tabkey得到的子组件
      {child}
    </View>)

}

```

子组件实现：
```jsx harmony
import {createElement, PureComponent, render} from 'rax';
import {View, Text} from 'nuke';
import style from "./style.less"
export default class TabBarItem extends PureComponent{
    constructor(props){
        super(props);
    }
    render(){
        return(
            <View style={style.children}>
                {this.props.children}
            </View>
        )
    }
}
```
