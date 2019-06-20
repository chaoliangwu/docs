# `PyListAuto`长列表
封装了大部分的`ListView`功能，无需自己指定`下拉刷新`以及`无限滚动`等事件，只需按照格式编写数据加载方法

## 调用方式

```jsx harmony
<PyListAuto  
  ref="pylist"  
  checkedValue={checkedValue}  
  dataSource={this.controller.initList.bind(this)} 
  renderItem={this.renderItem.bind(this)}  
  onChange={(value) => {
    this.setState({ checkedValue: value });  
  }} 
/>
```
 - `checkedValue` 含有复选框时的已选中数据
 - `dataSource` 数据加载方法
 - `renderItem` 行渲染方法
 - `onChange` 选择事件

## `dataSource`数据加载方法
- 方法自动提供一个参数`pageNo`，为当前页码。
- 需返回一个`Promise`对象，数据格式为：
```json
{
  listData:[], //当前页的数据
  total:0//查询总数
}
```

#### 举例：

```jsx harmony
   initList(pageNo) {
    return new Promise((resolve,reject)=>{
      const {pageSize} = this.state;
      const fields='num_iid,title,price,num';
      const param = {
        page_no: pageNo,
        page_size: pageSize,
      };
      const result =itemsOnsaleGet(fields, param).then(result=>{
        if (result) {
        resolve ({
          listData: result.items,
          total: result.total
        });
      }else{
        resolve({
          listData: [],
          total: 0
        });
      }
      }).catch((err) => { 
        reject(err);
      })
  })   
}
```

#### 或者使用ES6的`async`语法糖

``` jsx harmony
  async initList(pageNo) {
    const {pageSize} = this.state;
    const fields='num_iid,title,price,num';
    const param = {
      page_no: pageNo,
      page_size: pageSize,
    };
    const result =await itemsOnsaleGet(fields, param)
      .catch((err) => { PyDialog.alert(JSON.stringify(err)); })
    if (result) {
      return {
        listData: result.items,
        total: result.total
      };
    }
    return {
      listData: [],
      total: 0
    };
  }
```
::: tip 提示：
 使用过程中无需关心`pageNo`的相关计算，组件内部已经对其进行了处理，只需要将其当做入参传给数据加载方法
:::

## `renderItem`
该方法提供两个参数`item`和`index`
```jsx harmony
renderItem(item,index) {
    return (
      <View>
          <Checkbox value={item} />   
        <Text>{item.name}</Text>      
      </View>
    );
  }
```
- 可根据列表用途对行渲染方法进行定制，或者直接调用公共组件`ItemRow`
- `checkox`复选框按需渲染

## 扩展
如果要实现列表的搜索或者其他功能，可以给组件指定`ref`，然后使用
`this.refs.pylist.initDataSource()`手动重新加载数据

## 实现原理
实现原理其实很麻瓜，就是简单的把之前需要手动控制的分页，下拉刷新，无限滚动，以及刷新时的加载样式等全部封装到组件内部自动控制。

可以帮我们
- 简化代码
- 避免业务无关的代码中的小失误
### `state`

```jsx harmony
this.state = {
      isRefreshing: false, //RefreshControl状态，是否正在加载
      refreshText: '↓ 下拉刷新', //下拉显示文字
      isLoading: false, //是否正在加载下一页
      listData: [], //数据列表
      total: '', //总数
      pageNo: 1 //当前页
    };
```
### `componentDidMount`
组件初始化完成后调用数据加载方法[`initDataSource`](/React/listView.html#initdatasource数据加载)

### `render`
调用千牛组件`ListView`
```jsx harmony
 render() {
    return (
      <View style={[style.list_container, this.props.style]}>
        <Checkbox.Group
          onChange={this.onChange}
          value={this.props.checkedValue}
          style={{ width: '750rem', flex: 1 }}
        >
          <ListView
            renderHeader={this.renderHeader.bind(this)}
            renderFooter={this.renderFooter.bind(this)}
            renderRow={this.renderItem.bind(this)}
            dataSource={this.state.listData}
            ref="mylist0"
            style={style.flex750}
            onEndReached={this.handleLoadMore.bind(this)}
          />
        </Checkbox.Group>
      </View>
    );
  }
```
### `initDataSource`数据加载
```jsx harmony
 /**
   * 加载数据
   * @param flag //是否清空原有数据,true:内部加载默认不清空，false:外部加载重置
   * @param callback //回调
   * @returns {Promise<void>}
   */
 async initDataSource(flag, callback) {
    const self = PyListAuto.$$instance;
      !flag&&self.setState({
        listData: [],
        total: ''
      });
    let { pageNo, listData } = self.state;
    const result = await self.props.dataSource(pageNo)
      .catch((err) => { PyDialog.alert(JSON.stringify(err)); });
    if (result.listData&&result.total) {
      if (pageNo===1) {
        listData = result.listData;
      } else {
        listData = [...listData, ...result.listData];
      }
      self.setState({
        listData,
        total: result.total
      });
    } else if (result.total===0) {
      self.setState({
        listData,
        total: 0
      });
    } else {
      console.error('请确认数据源返回格式！{listData:[],total:0}');
    }
    callback&&callback(); //执行回调，重置加载状态以及文字
  }
```

### `renderHeader`
```jsx harmony
 renderHeader = () => (
    <RefreshControl
      style={style.refresh}
      refreshing={this.state.isRefreshing}
      onRefresh={this.handleRefresh.bind(this)}
    >
      <Text style={style.loadingText}>{this.state.refreshText}</Text>
    </RefreshControl>
  )
```
- `listView`头部，跟随加载状态切换`加载中`和`下拉刷新`文字
### `renderFooter`
```jsx harmony
 renderFooter = () => {
    const { total, listData: data } = this.state;
    const _total = total === '' ? -1 : total;
    if (_total > data.length || total === '') {
      return (
        <View style={[style.loading, this.props.opacity && { marginBottom: '102rem' }]}>
          <Text style={style.loadingText}>加载中...</Text>
        </View>
      );
    }
    if (data && data.length === 0) {
      return (
        <Blank
          type={this.props.blankType}
          customPicUrl={this.props.blankCustomPicUrl}
          msg={this.props.blankMsg || '没有符合条件的宝贝'}
        />
      );
    }
    return (
      <View style={[style.loading, this.props.opacity && { marginBottom: '102rem' }]}>
        <Text
          style={style.loadingText}
        >
          亲，没有更多宝贝了
        </Text>
      </View>
    );
  }
```
- `listView`底部文字以及空白页
### `renderItem`
```jsx harmony
 renderItem(item, index) {
    if (this.props.renderItem) {
      return this.props.renderItem(item, index);
    }
  }
```
### `handleRefresh`
```jsx harmony
 handleRefresh() {
    this.setState({ isRefreshing: true, refreshText: '加载中...', pageNo: 1 });
    this.initDataSource(true, () => {
      this.refs.mylist0.resetLoadmore();
      this.setState({ isRefreshing: false, refreshText: '↓ 下拉刷新' });
    });
  }
```
- 下拉刷新实现，重置当前页码，拉取数据
### `handleLoadMore`
```jsx harmony
 handleLoadMore() {
    const { total, listData: data } = this.state;
    if (total > data.length && !this.state.isLoading) {
      this.setState({ pageNo: this.state.pageNo+1, isLoading: true });
      this.initDataSource(true, () => {
        this.setState({ isLoading: false });
      });
    }
  }
```
- 下拉加载更多，判断是否存在下一页，如果存在拉取下一页，不存在下一页则不触发

::: tip 提示
具体实现以及用例可以参考普云商品移动端批量修改选择宝贝页面
:::
