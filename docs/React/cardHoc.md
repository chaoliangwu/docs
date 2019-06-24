## 简介
将弹出式卡片封装成高阶组件，应对不同的场景需求，只需传入不同的内容组件，不需要弹窗的弹出关闭以及键盘高度适配等问题。

<Picture src="card1.jpg" name="组件弹出" width = "300"/>

<Picture src="card2.jpg" name="呼出键盘自适应高度" width = "300"/>

## 调用方式

```jsx harmony
const option = {
      data:[],
      height: 990,
      title: '材质成分'
    };
cardHoc(ContentComponent)(option).show().then((data) => {
  
    });
```
- `ContentComponent`

    被修饰的组件，即卡片内部显示的内容。可以是一个`View`可以是一个`Input`也可以是自己编写的组件等等。
- `option`  
    - `option.height` 组件默认高度，如果呼出键盘，该组件会自动判断是否超出屏幕范围而进行高度适配。
    - `option.title` 组件标题
    - `option.loading` 是否显示加载动画
- `option`会作为组件`props`向下传递给`ContentComponent`,即在`ContentComponent`内部可以使用`this.props`获取到`option`中的所有值
- 该组件返回一个`Promise`对象，可以在`ContentComponent`中通过`this.props.resolve(data)`来返回结果。
## ContentComponent示例
```jsx
import { createElement, Component } from 'rax';
import { View, Text, TouchableHighlight, ScrollView } from 'nuke';
import style from './style.less';
import PyButton from '../../../components2/pyButton/PyButton';

export default class ContentComponent extends Component {
  constructor(props) {
    super(props);
    this.state = {};
  }

  render() {
    return (
      <View style={[style.content]}>
          <PyButton
            title="确定"
            onPress={this::this.save}
          />
      </View>
    );
  }
  save() {
    this.props.resolve({action:'保存'});
  }

}
```

##  源码

```jsx harmony
import {
  createElement, render, Component, unmountComponentAtNode,
} from 'rax';
import {
  View, Text, TouchableHighlight, Icon
} from 'nuke';
import QN from 'QAP-SDK';
import style from './style.less';
import doTransition from '$util/PyTransition';
import { register } from '$util/heightProvider';
import { logout } from '../../util/heightProvider';

const { height: screenHeight, width: screenWidth }= screen;
const heightMax = (screenHeight -200) / (screenWidth / 750);// 屏幕最大高度


/**
 * @param WrappedComponent  被装饰的组件
 * @returns {function(*): {show(): (*|undefined), new(*=): Card, prototype: Card}}
 */
export default function cardHoc(WrappedComponent) {
  return function doWrap(option) { // 返回一个函数，对option进行处理
    return class Card extends Component { // 将接收的组件组装成新组件
      /**
       * 将组件插入dom底部
       * @returns {Promise<any>}
       */
      static show() {
        option.loading&&QN.showLoading();
        if (!Card.isExist) {
          Card.isExist = true;
          Card.dom = document.createElement('div');
          document.body.appendChild(Card.dom);
          render(<Card />, Card.dom);
          return new Promise((resolve, reject) => {
            Card.promise = { resolve, reject };
          });
        }
      }

      componentDidMount() {
        // 加载动画以及是否显示loading
        option.loading&&QN.hideLoading();
        doTransition(this.refs.wrap, { backgroundColor: 'rgba(0,0,0,0.4' });
        doTransition(this.refs.body, { transform: `translateY(${-Card.bottom})` });
      }

      constructor(props) {
        super(props);
        Card.instance = this;
        const keyBoardHeight = register(Card);// 参见之前的文章，heightProvider
        let height = option.height||500; // 默认高度500
        // 如果键盘高度加内容高度超出屏幕范围，固定为最大高度
        height = height+keyBoardHeight>heightMax?heightMax-keyBoardHeight:height;
        this.state = {
          keyBoardHeight,
          height
        };
        Card.bottom = height;
      }

      /**
       * 组件销毁
       */
      destroy() {
        doTransition(this.refs.wrap, { backgroundColor: 'rgba(0,0,0,0)' });
        doTransition(this.refs.body, { transform: `translateY(${Card.bottom})` }, null, () => {
          logout(Card);
          unmountComponentAtNode(Card.dom);
          document.body.removeChild(Card.dom);
          Card.isExist = false;
        });
      }

      render() {
        const { keyBoardHeight, height } = this.state;
        const { title } = option;
        const pureHeight = height+keyBoardHeight>heightMax?heightMax-keyBoardHeight:height;
        return (
          <View ref="wrap" onClick={this.destroy.bind(this)} style={[style.dialogWrap, { height: screenHeight }]}>
            <View ref="body" onClick={() => {}} style={[style.body, { bottom: -Card.bottom, height: pureHeight }]}>
              <View style={style.header}>
                <Text style={style.headerText}>{title}</Text>
                <TouchableHighlight style={style.closeIcon} onPress={this.destroy.bind(this)}>
                  <Icon style={{ color: '#666666' }} name="close" />
                </TouchableHighlight>
              </View>
              <View style={[style.content, { flex: 1 }]}>
                {/*
                  在内容区域渲染传入的组件，并将option和promise钩子作为props向下传递
                */}
                {WrappedComponent
                &&<WrappedComponent {...option} resolve={this.resolve.bind(this)} />}
              </View>
            </View>
          </View>
        );
      }

      /**
       * promsie钩子，返回结果并销毁组件
       * @param result
       */
      resolve(result) {
        Card.promise.resolve(result);
        this.destroy.call(this);
      }
    };
  };
}


```
