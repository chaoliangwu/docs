## 引入
首先看这么一个例子
```jsx harmony
setTimeout(function() {
    console.log('timeout1');
})
new Promise(function(resolve) {
    console.log('promise1');
    for(var i = 0; i < 1000; i++) {
        i == 99 && resolve();
    }
    console.log('promise2');
}).then(function() {
    console.log('then1');
})
console.log('global1');
```
上面一段代码跑下来，执行顺序是怎么样的？如果没有对`JavaScript`的`Event Loop`不了解，那么肯定一头雾水。

OK，那我就先抛出结论，然后以例子与图示详细给大家演示事件循环机制。
```
promise1
promise2
global1
then1
timeout1
```

## 什么是 Event Loop
事件循环机制从整体上的告诉了我们所写的JavaScript代码的执行顺序。

::: tip
因为**chrome**浏览器中新标准中的事件循环机制与**nodejs**类似，因此此处就整合**nodejs**一起来理解，其中会介绍到几个**nodejs**有，但是浏览器中没有的API，大家只需要了解就好，不一定非要知道她是如何使用。比如`process.nextTick` `setImmediate`
:::

- 我们知道JavaScript的一大特点就是`单线程`，而这个线程中拥有唯一的一个事件循环。

- JavaScript代码的执行过程中，除了依靠函数调用栈来搞定函数的执行顺序外，还依靠任务队列`task queue`来搞定另外一些代码的执行。
 <Picture src="loop/fifo.jpg"/>
- 一个线程中，事件循环是唯一的，但是任务队列可以拥有多个。

- 任务队列又分为`macro-task 宏任务`与`micro-task 微任务`。

- setTimeout/Promise等我们称之为`任务源`。而进入任务队列的是他们指定的具体执行任务。

- 来自不同任务源的任务会进入到不同的任务队列。其中setTimeout与setInterval是同源的。

- 事件循环的顺序，决定了JavaScript代码的执行顺序。它从script(整体代码)开始第一次循环。之后全局上下文进入函数调用栈。直到调用栈清空(只剩全局)，然后执行所有的micro-task。当所有可执行的micro-task执行完毕之后。循环再次从macro-task开始，找到其中一个任务队列执行完毕，然后再执行所有的micro-task，这样一直循环下去。

- 其中每一个任务的执行，无论是macro-task还是micro-task，都是借助函数调用栈来完成。

macro-task | micro-task
:-:|:-:
script(整体代码)|process.nextTick
setTimeout|Promise
setInterval|Object.observe
setImmediate|MutationObserver
I/O|...
UI rendering|...

纯文字表述确实有点干涩，因此，这里我们通过上述的例子，来逐步理解事件循环的具体顺序。

## 单次循环的执行过程

还是上面的例子
```jsx harmony
setTimeout(function() {
    console.log('timeout1');
})

new Promise(function(resolve) {
    console.log('promise1');
    for(var i = 0; i < 1000; i++) {
        i == 99 && resolve();
    }
    console.log('promise2');
}).then(function() {
    console.log('then1');
})

console.log('global1');
```

### 开始——宏任务队列

首先，事件循环从宏任务队列开始，这个时候，宏任务队列中，只有一个`script 整体代码`任务。每一个任务的执行顺序，都依靠函数调用栈来搞定，而当遇到任务源时，则会先分发任务到对应的队列中去，所以，上面例子的第一步执行如下图所示。

 <Picture src="loop/1.png" name="首先script任务开始执行，全局上下文global入栈"/>

### 任务分发

- `script`任务执行时首先遇到了`setTimeout`。`setTimeout`为一个宏任务源，那么他的作用就是将任务分发到它对应的队列中。
```jsx harmony
setTimeout(function() {
    console.log('timeout1');
})
```
 <Picture src="loop/2.png" name="宏任务timeout1进入setTimeout队列"/>
 
- `script`执行时遇到`Promise`实例。`Promise`构造函数中的第一个参数，是在`new`的时候执行，因此不会进入任何其他的队列，而是直接在当前任务直接执行。
 <Picture src="loop/3.png" name="promise1入栈执行，这时promise1被最先输出"/>
 <Picture src="loop/4.png" name="resolve在for循环中入栈执行"/>
 
::: tip
构造函数执行时，里面的参数进入函数调用栈执行。for循环不会进入任何队列，因此代码会依次执行，所以这里的`promise1`和`promise2`会依次输出。
:::
- **`.then`则会被分发到`micro-task`的`Promise`队列中去。**

 <Picture src="loop/5.png" name="构造函数执行完毕的过程中，resolve执行完毕出栈，promise2输出，promise1页出栈，then执行时，Promise任务then1进入对应队列"/>
> 


- `script`任务继续往下执行，最后只有一句输出了`globa1`，然后，全局任务执行完毕。

### 执行所有的可执行的微任务

第一个宏任务`script`执行完毕之后，就开始执行所有的可执行的微任务。这个时候，微任务中，只有`Promise`队列中的一个任务`then1`，因此直接执行就行了，执行结果输出`then1`，当然，他的执行，也是进入函数调用栈中执行的。
 <Picture src="loop/6.png" name="执行所有的微任务"/>

### 首轮循环结束
当所有的`micro-tast`执行完毕之后，表示第一轮的循环就结束了。这个时候就得开始第二轮的循环。
### 继续循环
- 第二轮循环仍然从宏任务`macro-task`开始。
 <Picture src="loop/7.png" name="微任务被清空"/>
 
- 我们发现宏任务中，只有在`setTimeout`队列中还要一个`timeout1`的任务等待执行，因此就直接执行即可。
 <Picture src="loop/8.png" name="timeout1入栈执行"/>

这个时候宏任务队列与微任务队列中都没有任务了，所以代码就不会再输出其他东西了。

## 复杂的例子
上个例子比较简答，涉及到的队列任务并不多，
因此读懂了它还不能全面的了解到事件循环机制的全貌。
所以我们整理一个复杂一点的例子解析一番，相信读懂之后，事件循环这个问题，也就不是什么难事了。

<<< @/docs/Learning/test/eventloop.js

这个例子看上去有点复杂，乱七八糟的代码一大堆，不过不用担心，我们一步一步来分析一下。
### 第一步
宏任务`script`首先执行。全局入栈。`glob1`输出。
 <Picture src="loop/hard/1.png" name="script首先执行"/>
 
### 第二步
执行过程遇到`setTimeout`。`setTimeout`作为任务分发器，将任务分发到对应的宏任务队列中。
```jsx harmony
setTimeout(function() {
    console.log('timeout1');
    process.nextTick(function() {
        console.log('timeout1_nextTick');
    })
    new Promise(function(resolve) {
        console.log('timeout1_promise');
        resolve();
    }).then(function() {
        console.log('timeout1_then')
    })
})
```
 <Picture src="loop/hard/2.png" name="timeout1进入对应队列"/>
 
###第三步
执行过程遇到`setImmediate`。`setImmediate`也是一个宏任务分发器，
将任务分发到对应的任务队列中。
::: tip
`setImmediate`的任务队列会在`setTimeout`队列的后面执行，即所有的`setTimeout`任务执行完毕后，才会开始执行`setImmediate`的任务队列
:::
```jsx harmony
setImmediate(function() {
    console.log('immediate1');
    process.nextTick(function() {
        console.log('immediate1_nextTick');
    })
    new Promise(function(resolve) {
        console.log('immediate1_promise');
        resolve();
    }).then(function() {
        console.log('immediate1_then')
    })
})
```
 <Picture src="loop/hard/3.png" name="进入setImmediate队列"/>
 
### 第四步
执行遇到`nextTick`，`process.nextTick`是一个微任务分发器，它会将任务分发到对应的微任务队列中去。
```jsx harmony
process.nextTick(function() {
    console.log('glob1_nextTick');
})
```
<Picture src="loop/hard/4.png" name="nextTick"/>

### 第五步
执行遇到`Promise`。`Promise`的`then`方法会将任务分发到对应的微任务队列中，但是它构造函数中的方法会直接执行。
因此，`glob1_promise`会第二个输出。
```jsx harmony
new Promise(function(resolve) {
    console.log('glob1_promise');
    resolve();
}).then(function() {
    console.log('glob1_then')
})

```
<Picture src="loop/hard/5.png" name="先是函数调用栈的变化"/>


<Picture src="loop/hard/6.png" name="然后glob1_then任务进入队列"/>

###第六步 
执行遇到第二个`setTimeout`。
```jsx harmony
setTimeout(function() {
    console.log('timeout2');
    process.nextTick(function() {
        console.log('timeout2_nextTick');
    })
    new Promise(function(resolve) {
        console.log('timeout2_promise');
        resolve();
    }).then(function() {
        console.log('timeout2_then')
    })
})
```
<Picture src="loop/hard/7.png" name="timeout2进入对应队列"/>

### 第七步
先后遇到`nextTick`与`Promise`
```jsx harmony
process.nextTick(function() {
    console.log('glob2_nextTick');
})
new Promise(function(resolve) {
    console.log('glob2_promise');
    resolve();
}).then(function() {
    console.log('glob2_then')
})
```
<Picture src="loop/hard/8.png" name="glob2_nextTick与Promise任务分别进入各自的队列"/>

###第八步
再次遇到`setImmediate`
```jsx harmony
setImmediate(function() {
    console.log('immediate2');
    process.nextTick(function() {
        console.log('immediate2_nextTick');
    })
    new Promise(function(resolve) {
        console.log('immediate2_promise');
        resolve();
    }).then(function() {
        console.log('immediate2_then')
    })
})
```
<Picture src="loop/hard/9.png" name="nextTick"/>


这个时候，`script`中的代码就执行完毕了，
执行过程中，遇到不同的任务分发器，就将任务分发到各自对应的队列中去。接下来，将会执行所有的微任务队列中的任务。

**其中，`nextTick`队列会比`Promie`先执行。`nextTick`中的可执行任务执行完毕之后，才会开始执行`Promise`队列中的任务。**

当所有可执行的微任务执行完毕之后，这一轮循环就表示结束了。下一轮循环继续从宏任务队列开始执行。

这个时候，script已经执行完毕，所以就从setTimeout队列开始执行。
<Picture src="loop/hard/10.png" name="第二轮循环初始状态"/>


`setTimeout`任务的执行，也依然是借助函数调用栈来完成，并且遇到任务分发器的时候也会将任务分发到对应的队列中去。

::: warning
这里的执行顺序，或者执行的优先级在不同的场景里由于实现的不同会导致不同的结果，包括node的不同版本，不同浏览器等都有不同的结果。
:::
- **在`node`环境中,当`setTimeout`中所有的任务执行完毕之后，才会再次开始执行微任务队列。并且清空所有的可执行微任务。**

- **在`浏览器`标准环境中(比如说谷歌`webkit`内核)，每当`setTimeout`队列中的`一个`任务执行完成，便会清空所有的可执行微任务**

`setTiemout`队列产生的微任务执行完毕之后，循环则回过头来开始执行`setImmediate`队列。仍然是先将`setImmediate`队列中的任务执行完毕，再执行所产生的微任务。

当`setImmediate`队列执行产生的微任务全部执行之后，第二轮循环也就结束了。

::: tip
当我们在执行`setTimeout`任务中遇到`setTimeout`时，
它仍然会将对应的任务分发到`setTimeout`队列中去，
但是该任务就得等到下一轮事件循环执行了。例子中没有涉及到这么复杂的嵌套，可以动手添加或者修改他们的位置来感受一下循环的变化。
:::
