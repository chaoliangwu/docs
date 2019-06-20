
> 重复是不可能的，这辈子都不可能写重复的代码。

当然，这句话分分钟都要被打脸。我们烦恼于频繁修改的需求。

虽然我们不能改变别人，但我们却可以尝试去做的更好，我们需要抽象，封装重复的功能或者逻辑，而不是老旧的重复着机械的复制粘贴修改。

那么我们如何去封装 React 中的组件以及逻辑呢？

在本文中，我们将深入探讨三种模式，以便了解我们为什么需要它们，以及如何正确地使用它们来构建更好的 React 应用。
## 引入
`组件`是 React 代码复用的主要单元，但如何分享一个组件封装到其他需要相同 state 组件的状态或行为并不总是很容易。

### 需求
引入React官网中的例子，我们需要一个 商品 List 组件，它订阅外部数据源，用以渲染商品列表：
```jsx harmony
class ItemList extends React.Component {
  constructor(props) {
    super(props);
    this.handleChange = this.handleChange.bind(this);
    this.state = {
      // 假设 "DataSource" 是个全局范围内的数据源变量
      items: DataSource.getItems()
    };
  }
  componentDidMount() {
    // 订阅更改
    DataSource.addChangeListener(this.handleChange);
  }

  componentWillUnmount() {
    // 清除订阅
    DataSource.removeChangeListener(this.handleChange);
  }

  handleChange() {
    // 当数据源更新时，更新组件状态
    this.setState({
      items: DataSource.getItems()
    });
  }

  render() {
    return (
      <div>
        {this.state.items.map((item) => (
          <Item item={item} key={item.id} />
        ))}
      </div>
    );
  }
}
```
当光标在屏幕上移动时，组件在 `<p>` 中显示其坐标。

### 新需求
现在又来了一个需求，我们需要一个 订单 List 组件，它订阅外部数据源，用以渲染订单列表：

```jsx harmony
class OrderList extends React.Component {
  constructor(props) {
    super(props);
    this.handleChange = this.handleChange.bind(this);
    this.state = {
      // 假设 "DataSource" 是个全局范围内的数据源变量
      orders: DataSource.getOrders()
    };
  }
  componentDidMount() {
    // 订阅更改
    DataSource.addChangeListener(this.handleChange);
  }

  componentWillUnmount() {
    // 清除订阅
    DataSource.removeChangeListener(this.handleChange);
  }

  handleChange() {
    // 当数据源更新时，更新组件状态
    this.setState({
      orders: DataSource.getOrders()
    });
  }

  render() {
    return (
      <div>
        {this.state.order.map((order) => (
          <Order order={order} key={order.id} />
        ))}
      </div>
    );
  }
}
```
`ItemList` 和 `OrderList` 不同 - 它们在 `DataSource` 上调用不同的方法，且渲染不同的结果。但它们的大部分实现都是一样的：

- 在挂载时，向 `DataSource` 添加一个更改侦听器。
- 在侦听器内部，当数据源发生变化时，调用 `setState`。
- 在卸载时，删除侦听器。

可以想象，在一个大型应用程序中，这种订阅 `DataSource` 和调用 `setState` 的模式将一次又一次地发生。

**我们需要一个抽象，允许我们在一个地方定义这个逻辑，并在许多组件之间共享它。**


## HOC
`高阶组件`是 React 中用于复用组件逻辑的一种高级技巧。HOC 自身不是 React API 的一部分，它是一种基于 React 的组合特性而形成的设计模式。

具体而言，高阶组件是参数为组件，返回值为新组件的函数。
```js
const EnhancedComponent = higherOrderComponent(WrappedComponent);
```
**如何使用高阶组件解决上述问题?**
### 抽离公共逻辑
我们可以编写一个创建组件的函数，比如 ItemList 和 OrderList，订阅 DataSource。

该函数将接受一个子组件作为它的其中一个参数，该子组件将订阅数据作为 prop。

让我们编写函数 withDataSource：
```jsx harmony
// 此函数接受一个组件以及获取数据的方法
function withDataSource(WrappedComponent, getData) {
  // ...并返回另一个组件...
  return class extends React.Component {
    constructor(props) {
      super(props);
      this.handleChange = this.handleChange.bind(this);
      this.state = {
        data: getData()
      };
    }

    componentDidMount() {
       // 假设 "DataSource" 是个全局范围内的数据源变量
      // ...负责订阅相关的操作...
      DataSource.addChangeListener(this.handleChange);
    }

    componentWillUnmount() {
      DataSource.removeChangeListener(this.handleChange);
    }

    handleChange() {
      this.setState({
        data: getData()
      });
    }

    render() {
      // ... 使用新数据渲染被包装的组件!
      // 请注意，我们可能还会传递其他属性
      return <WrappedComponent data={this.state.data} {...this.props} />;
    }
  };
}
```
第一个参数是被包装组件。第二个参数是订阅数据的方法。
### 组件复用
#### 商品列表
```jsx harmony
class List extends React.Component {
  constructor(props){
    super(props);
  }
  //...
  render() {
    return (
        <div>
        {this.props.data.map(item=>{
          <Item item={item} key={item.id} />
        })}
        </div>
    );
  }
}
```
```jsx harmony
const ItemList = withDataSource(ItemList,DataSource.getItems);
```
这里用定义好的高阶组件包装`List`组件，他会将items列表作为props注入List

当渲染 ItemList 时， withDataSource 将传递一个 data prop，其中包含从 DataSource.getItems 检索到的最新商品

#### 订单列表
```const ItemList = withDataSource(List,DataSource.getItem);```
```jsx harmony
class List extends React.Component {
  constructor(props){
    super(props);
  }
  //...
  render() {
    return (
        <div>
        {this.props.data.map(item=>{
          <Order order={order} key={order.id} />
        })}
        </div>
    );
  }
}
```
```jsx harmony
const OrderList = withDataSource(List,DataSource.getOrders);
```
这里用定义好的高阶组件包装`List`组件，他会将items列表作为props注入List

当渲染 OrderList 时， withDataSource 将传递一个 data prop，其中包含从 DataSource.getOrders 检索到的最新订单
### 总结
HOC 不会修改传入的组件，也不会使用继承来复制其行为。相反，HOC 通过将组件包装在容器组件中来组成新组件。HOC 是纯函数，没有副作用。

被包装组件接收来自容器组件的所有 prop，同时也接收一个新的用于 render 的 data prop。HOC 不需要关心数据的使用方式或原因，而被包装组件也不需要关心数据是怎么来的。

与组件一样，高阶组件 和包装组件之间的契约完全基于之间传递的 props。这种依赖方式使得替换 HOC 变得容易，只要它们为包装的组件提供相同的 prop 即可。
## render prop
术语 `render prop` 是指一种在 React 组件之间使用一个值为函数的 prop 共享代码的简单技术。

具有 render prop 的组件接受一个函数，该函数返回一个 React 元素并调用它而不是实现自己的渲染逻辑。

更具体地说，render prop 是一个用于告知组件需要渲染什么内容的函数 prop。

```jsx harmony
<DataProvider render={data => (
  <h1>Hello {data.target}</h1>
)}/>
```
**如何使用render prop组件解决上述问题?**
### 抽离公共逻辑
```jsx harmony
class List extends React.Component {
  constructor(props) {
    super(props);
    this.handleChange = this.handleChange.bind(this);
    this.state = {
      list: props.getList()
    };
  }
  componentDidMount() {
    // 订阅更改   假设 "DataSource" 是个全局范围内的数据源变量
    DataSource.addChangeListener(this.handleChange);
  }

  componentWillUnmount() {
    // 清除订阅
    DataSource.removeChangeListener(this.handleChange);
  }

  handleChange() {
    // 当数据源更新时，更新组件状态
    this.setState({
      list: props.getList()
    });
  }

  render() {
    return (
      <div>
        {this.props.render(this.state)} // props.render为一个方法，该方法接受一个list对象
      </div>
    );
  }
}
```
### 组件复用
#### 商品列表
```jsx harmony
class Page extends React.Component {
  //...
  render() {
    return (
        <List getList={DataSource.getItems}
              render={list=>(
                <div>{list.map(item=>(<Item item={item} key={item.id} />))} </div>
             )} /> 
    );
  }
}
```
#### 订单列表
```jsx harmony
class Page extends React.Component {
  //...
  render() {
    return (
      <List getList={DataSource.getOrders}
                    render={list=>(
                      <div>{list.map(item=>(<Order order={order} key={order.id} />))} </div>
                   )} /> 
    );
  }
}
```
::: tip
render prop 是因为模式才被称为 render prop ，
你不一定要用名为 render 的 prop 来使用这种模式。
事实上， 任何被用于告知组件需要渲染什么内容的函数 prop 在技术上都可以被称为 `render prop`
:::

### 另一种方式
尽管之前的例子使用了 render，我们也可以简单地使用 children prop！
```jsx harmony
class List extends React.Component {
  render() {
      return (
        <div>
          {this.props.children(this.state)} // props.render为一个方法，该方法接受一个list对象
        </div>
      );
    }
}
```

```jsx harmony
<List getList={DataSource.getItems}
      children={list=>(
      <div>{list.map(item=>(<Item item={item} key={item.id} />))} </div>
 )} /> 
```
::: tip
children prop 并不真正需要添加到 JSX 元素的`attributes`列表中。相反，你可以直接放置到`元素的内部`！
:::
```jsx harmony
<List getList={DataSource.getItems}>
      {list=>(
        <div>{list.map(item=>(<Item item={item} key={item.id} />))} </div>
      )}
 <List/> 
```
### 注意事项
**将 Render Props 与 React.PureComponent 一起使用时要小心。**

如果你在 render 方法里创建函数，
那么使用 render prop 会抵消使用 React.PureComponent 带来的优势。
因为这种情况下父组件每次渲染对于 render prop 将会生成一个新的值，这会导致浅比较 props 的时候总会得到 false。

为了绕过这一问题，有时你可以定义一个 prop 作为实例方法，类似这样：
```jsx harmony
class Page extends React.Component {
  // 定义为实例方法，`this.renderItem`始终
  // 当我们在渲染中使用它时，它指的是相同的函数
  renderItem(list) {
    return (
     <div>{list.map(item=>(<Item item={item} key={item.id} />))} </div>
    )
  }
    return <Item Item={Item} />;
  }

  render(){
    return (
      <List getList={DataSource.getItems}>
          {this.renderItem()}
       <List/> 
    );
  }
}
```
## Hook
`Hook` 是 React 16.8 的新增特性。它可以让你在不编写 class 的情况下使用 state 以及其他的 React 特性。

通过自定义 Hook，可以将组件逻辑提取到可重用的函数中。

目前为止，在 React 中有两种流行的方式来共享组件之间的状态逻辑: `render props` 和`高阶组件`，现在让我们来看看 Hook 是如何在让你不增加组件的情况下解决相同问题的

**如何使用自定义 Hook解决上述问题?**
### 抽离公共逻辑
当我们想在两个函数之间共享逻辑时，我们会把它提取到第三个函数中。而组件和 Hook 都是函数，所以也同样适用这种方式。

自定义 Hook 是一个函数，其名称以 “use” 开头，函数内部可以调用其他的 Hook。 
```jsx harmony
import React, { useState, useEffect } from 'react';

function useData(getData) {
  const [list, setList] = useState([]);
  useEffect(() => {
    function handleChange() {
      setList(getData());
    }

    DataSource.addChangeListener(this.handleChange);
    return () => {
      DataSource.removeChangeListener(this.handleChange);
    };
  });
  }
  return list;
```
此处 useData 的 Hook 目的是订阅某个列表。这就是我们需要将 获取某列表的方法 getData 作为参数并且返回list列表的原因。
### 组件复用
现在让我们看看应该如何使用自定义 Hook。

我们一开始的目标是在 ItemList 和 OrderList 组件中去除重复的逻辑，即：这两个组件都想订阅DataSource的变化。

现在我们已经把这个逻辑提取到 useData 的自定义 Hook 中，然后就可以使用它了：
#### 商品列表
```jsx harmony
function ItemList(props) {
  const list = useData(DataSource.getItems);
  return (
    <div>
    {list.map(item=>(<Item item={item} key={item.id}/>))}
    </div>
  )
}
```
#### 订单列表
```jsx harmony
function OrderList(props) {
  const list = useData(DataSource.getOrders);
  return (
    <div>
    {list.map(item=>(<Order order={order} key={order.id}/>))}
    </div>
  )
}
```

这段代码运行结果等价于render props 和 高阶组件吗?等价，它的工作方式完全一样。

如果仔细观察，会发现我们没有对其行为做任何的改变，我们只是将两个函数之间一些共同的代码提取到单独的函数中。

自定义 Hook 是一种自然遵循 Hook 设计的约定，而并不是 React 的特性。

## 对比

- `render prop` 粒度更细，对于局部操作非常适用，可以更好的进行局部优化。而`HOC`可以传入多个参数，适用范围广,倾向于更好地执行更复杂的操作。
HOC属于**无入侵式扩展**，只需要用高阶组件合理地去包裹原始组件，而不需要创建新组件。
- `Hooks` 使我们可以更优雅，更简单的复用逻辑。Hooks出来之后，前面的两个看似强大的模式都成了纸老虎。其他不说，首先从代码量上，Hooks就已经完胜了。
并且随着Hooks被逐渐推广，更多Hooks的潜能也会被逐渐发掘出来。

## 总结
- 一般情况下，使用 Hooks 就可以了
- 如果希望将特性仅应用于组件树的一部分，使用 Render Props
- 如果希望特性能够被优雅地组合复用，使用 HOCs
