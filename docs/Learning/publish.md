## 观察者模式
### 介绍
观察者模式是一种设计模式，其中一个**主题**（也可以叫做**发布者**）根据**观察者**维护一个**观察者列表**，自动通知他们对状态的任何更改。

观察者模式里面，发布者 `Subject` ，或者叫 `Observable` ，需要在内部维护一套观察者`Observer`的集合，这些 `Observer` 实现相同的接口，当被观察者数据发生变化时，统一为观察者集合调用方法。


<Picture src="observer/observer.jpg" name="观察者模式"/>

### 简单实现
#### 发布者
```jsx harmony
class Subject{
  constructor(){
    this.subs = [];//观察者集合
  }
  /**
  * 添加观察者
  * @param sub
  */
  addSub(sub){
    this.subs.push(sub);
  }
  /**
  * 通知
  */
  notify(){
    this.subs.forEach(sub=> {
      sub.update();
    });
  }
}
```
发布者内部维护了一个`subs`集合，他的`notify`方法对集合进行遍历，统一调用观察者的`update`方法
#### 观察者
```jsx harmony
class Observer{
  update(){
    console.log('update');
  }
}
```
观察者实现相同的`update`接口
#### 测试
```jsx harmony
let subject = new Subject();
let ob = new Observer();
let ob2 = new Observer();
//添加观察者
subject.addSub(ob);
subject.addSub(ob2);
//发布消息调用观察者的更新方法
subject.notify();
```
可以看到控制台打印了两次update


## 发布-订阅模式
### 介绍
 在发布订阅模式中，发布者和订阅者之间多了一个**调度中心**。
 
 消息不会直接发送给特定的订阅者。
 
 订阅者把自己想订阅的**消息**以及**处理程序**注册到调度中心，当发布者发布消息到调度中心，由调度中心统一调度订阅者注册到调度中心的处理程序。
 
 <Picture src="observer/event.jpg" name="发布订阅模式"/>
 
### 简单实现
基于**发布-订阅模式**的`Event Bus`
#### 初始化
利用`ES6`的`class`关键字对`Event`进行初始化,包括`Event`的事件清单和监听者上限。

选择`Map`作为储存事件的结构,因为作为键值对的储存方式`Map`比一般对象更加适合,操作起来也更加简洁。
```jsx harmony
class EventEmeitter {
  constructor() {
    this._events = this._events || new Map(); // 储存事件/回调键值对
    this._maxListeners = this._maxListeners || 10; // 设立监听上限
  }
}
```
#### 监听与触发
触发监听函数我们可以用`apply`与`call`两种方法,在少数参数时`call`的性能更好,多个参数时`apply`性能更好。

```jsx harmony
// 监听名为type的事件
EventEmeitter.prototype.addListener = function(type, fn) {
  const handler = this._events.get(type); // 获取对应事件名称的处理程序清单
    if (!handler) { // 如果没有处理程序注册，自动注册该程序
      this._events.set(type, fn);
    } else if (handler && typeof handler === 'function') {
      this._events.set(type, [handler, fn]); // 多个监听者需要用数组储存
    } else {
      handler.push(fn); // 已经有多个监听者,那么直接往数组里push函数
    }
};

// 触发名为type的事件
EventEmeitter.prototype.emit = function(type, ...args) {
   const handler = this._events.get(type);
      if (Array.isArray(handler)) { // 如果是一个数组说明有多个监听者,需要依次此触发里面的函数
        for (let i = 0; i < handler.length; i++) {
          if (args.length > 0) {
            handler[i].apply(this, args);
          } else {
            handler[i].call(this);
          }
        }
      } else { // 单个函数的情况直接触发即可
        if(handler){
          args.length > 0 ? handler.apply(this, args):handler.call(this);
        }
      }
      return true;
};
```

#### 移除监听
用 `removeListener` 函数移除监听函数,但是匿名函数是无法移除的
```jsx harmony
EventEmeitter.prototype.removeListener = function(type, fn) {
 const handler = this._events.get(type); // 获取对应事件名称的处理程序清单
    if(!handler) {
      return false;
    }
    if(!fn){ // 如果没有传入具体的处理程序，表示需要取消key对应消息的所有订阅
      this._events.delete(type);
      return true
    }
    if (handler && typeof handler === 'function') {
      this._events.delete(type);
    } else {
      let postion = handler.findIndex(func => func === fn); // 查找处理程序
      if (postion !== -1) {
        handler.splice(postion, 1);
        if (handler.length === 1) {  // 如果清除后只有一个函数,那么取消数组
          this._events.set(type, handler[0]);
        }
      } else {
        return this;
      }
    }
}

```
#### 测试
```jsx harmony
const Event = new EventEmeitter()
Event.addListener('add',(data)=>{
    console.log('event:add,data:'+data)
})
Event.addListener('add',()=>{
  console.log('event:add')
})
//发布消息
Event.emit('add',123)

```
可以看到控制台分别打印
```
event:add,data:123
event:add
```

## 差异
### 实现思路
- 观察者模式
    - 定义主题 `Subject`（发布者）
    - 定义观察者 `Observer`
    - 在发布者中注册观察者
    - 发布者发布消息，遍历观察者列表并分发消息
- 发布-订阅模式
    - 定义调度中心(包含事件订阅，事件移除，发布等)
    - 订阅者在调度中心订阅事件（将事件和处理程序注册到调度中心）
    - 发布者发布事件到调度中心，调度中心统一调度注册该事件的订阅者处理程序
    
### 通知订阅者的方式
- 观察者模式

    主体自己本身去遍历观察者列表，然后调用观察者的更新方法。

- 发布-订阅模式

    相比观察者模式多了个调度中心，由调度中心统一通知。

### 内部维护的内容
- 观察者模式

    主体内部维护了观察者，知道有哪些观察者在关注，需要主体去调度。

- 订阅-发布模式

    发布者不关心消息如何被订阅者使用，只负责发布消息到调度中心。
    
    订阅者不关心消息是被谁发出的，只监听消息的事件名。


### 总结

虽然两种模式都存在订阅者和发布者（观察者可认为是订阅者、主体可认为是发布者），但是观察者模式是由发布者调度的，而发布-订阅模式是统一由调度中心调的，所以观察者模式的订阅者与发布者之间是存在依赖的，而发布-订阅模式则不会。

另外，没必要纠结发布/订阅模式和观察者模式的区别，事实上，这两个模式非常相似，甚至可以相互替换，至于是否需要将 `Subject` 和 `ObserverList` 抽象成两个类来处理，答案也不是必须的，软件工程很重要的一点就是代码要怎么拆分，要拆分到什么粒度都是没有标准答案的。

---

关于**发布-订阅模式的应用**，可以参考下文：[基于**发布-订阅模式**以及**数据劫持**的双向绑定原理](/Learning/bind.html)



