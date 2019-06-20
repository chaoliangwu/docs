
最近刚刚完成了前端的发布宝贝实现，在这里做一个梳理总结
<!-- more -->
## 主界面
<Picture src="itemAdd/main.png" name="主界面" width="300" />

主界面作为整个模块的核心页面，承载所有子页面的数据收集，数据处理以及最终的数据拼接

### `constructor`
- `this.controller = new ItemAddController();`
> 控制主界面的各种函数
- `state`
```javascript
     this.state = {
      pic_category_id: '',//图片空间类目id,即（普云商品）
      seller_cids: {value: "", cid: ''},//店铺类目
      reg: { //表单验证，价格，库存，标题是否符合规范
        title: false,
        price: false,
        num: false
      }
      /**
      * 最重要的商品属性
      **/
      item: {  
        category: [],//所选宝贝分类=>eg. {根类目},{子类目},{叶子类目}，这么写的原因是为了降低category组件展示数据加载延迟
        props_must:false,//是否含有必填属性项
        cid: '',//所选类目id
        has_sku: false,商品是否含有销售属性
        has_normal_prop: false,
        sku_prop: {},//sku界面传来的属性
        props: '',//商品普通属性串
        input_str: '',自定义属性串
        input_pids: '',//自定义属性穿
        desc: [],//宝贝描述
        title: '',//标题
        price: '',//价格
        num: '',//库存
        /**
         * 图片数据
         */
        img: [],
        /**
         * 运费模板信息
         */
        postage: {
          name: '',
          template_id: '',
          address: '',
          item_weight: '',
          item_size: ''
        },
        address: { //发货地信息
          provinceId: '',
          provinceValue: '',
          cityId: '',
          cityValue: '',
        },
        /**
         * 采购地信息
         */
        purchase_option: {
          purchase_place: '国内',//采购地
          purchase_country: '',//采购国家
          delivery_place: {//发货地
            key: '1',
            value: '国内'
          },
          inventory_type: {//库存类型
            key: '1',
            value: '现货'
          },
        }
      },
}
```
> 主界面的`state`控制着用户对宝贝进行编辑后的所有数据处理以及展示

### `componentDidMount`
接下来，在页面渲染完成后，进行时间的绑定。由于`QAP`采用的是多页面架构，所以不同页面件的数据交互就需要通过`QAP`的事件机制来完成
```javascript
 const self = this
    /**
     * 图片选择
     */
    QN.on('App.itemAdd.picSelect', data => {
      this.controller.refreshImg.call(this, data)
    })
    /**
     * 采购地选择
     */
    QN.on('App.itemAdd.purchasePlace', data => {
      this.state.item.purchase_option = data
      this.setState({})
    })
    /**
     * sku编辑界面
     */
    QN.on('App.itemAdd.skuAdd', data => {
      Object.assign(self.state.item.sku_prop, data)
      self.state.item.price = data.min_price
      self.state.reg.price = true
      self.setState({})
    })
    /**
     * 宝贝属性选择
     */
    QN.on('App.itemAdd.propAdd', data => {
      self.state.item.input_pids = data.input_pids.join(',')
      self.state.item.input_str = data.input_str.join(',')
      self.state.item.props = data.props.join(';')
      self.setState({})
    })

    /**
     * 宝贝详情
     */
    QN.on('App.itemAdd.descSave', data => {
      self.state.item.desc = data
      self.setState({})
    })

    /**
     * 类目选择
     */
    QN.on('App.itemAdd.cidSelect', data => {
      self.setState({
        seller_cids: data
      })
    })
```
在界面加载完成后，判断用户图片空间是否存在普云商品发布目录，如果不存在给他新建一个
` this.controller.pic_space_folder_handler.call(this)`<a href='#pic_space_folder_handler'> >>>></a>
### `render`
主界面主要负责数据处理，它的视图比较简单，此处就不一一列举。
主要对表单验证自己实现了一个小组件。
```javascript
<ActionRow key={6}
           required
           label={'一口价'}
           type={'input'}
           htmlType={'number'}
           warn={'一口价须精确到小数点后两位'}
           value={this.state.item.price}
           onInput={(e) => {
             self.state.item.price = e.value
           }}
           warnReg={(value) => {
              const regPrice = /^\d+(\.\d{1,2})?$/,
                    flag = regPrice.test(value)
              self.state.reg.price = flag
              return flag
           }}
/>
```

`ActionRow` <a href='#actionrow'> >>>></a>

---
## 宝贝主图
<Picture src="itemAdd/main2.png" name="宝贝主图" width="300" />

<Picture src="itemAdd/main3.png" name="宝贝主图2" width="300" />

**这里复用了林立全的主图拖拽排序组件**

上传主图使用了三种方式，其中上传本地图片实现比较复杂：

1. 调用千牛协议

```javascript
     QN.app.invoke({
        api:'selectFiles',
        query:{
          actions : type,//选取方式，本地相册和拍照
          limit : limit,//图片数量
          representation:0.8, //图片质量比
          maxWidth:'750'//图片最大宽度
        }
    })
```
> 此协议可以得到图片的`local`地址:`file://localpath=%2fUsers%2f2b%2fDesktop%2ftest.txt`

2. 将图片进行`Base64`转码

```javascript
 QN.app.invoke({
    api:'getFileData',
    query:{
      uris : location
    }
  })
```

> 这里遇到一个问题，一次如果多个图片进行转换时，上面的是异步函数，如果用`Promise.all`一次执行多个，`IOS`可以正常转换，但是`Andriod`会报错，所以后期对图片转码进行了同步

```javascript
async upload (photos, cat_id) {
    const  promises = []
    for(let photo of photos){
      const guid = Util.guid(),
        uri = photo.uri,
        type = uri.slice(uri.lastIndexOf('.') + 1, uri.length),
        location = uri + '&mimetype=image/' + type,
        base64 = await getFileStream(location).catch(err=>console.error(err)),
        img = {name: guid + '.' + type, data: base64}
        promises.push(uploadFile(img, guid + '.' + type, cat_id))
    }
    return promises
  }
```

3.调用`TOP`接口上传图片到图片空间

```javascript
  QN.top.invoke({
    query: {
      method: 'taobao.picture.upload',
      img:img,
      picture_category_id:cat_id||0,
      client_type:'client:computer',
      image_input_title:title
    }
  })
```
> 这里有一个大坑，之前调用这个接口，直接把`Base64`当做入参`img`一直报错，接口文档里也没有说明，后来才发现这个`img`入参是有格式要求的>>>
`img = {name: guid + '.' + type, data: base64}`



---

## 类目选择器`category`
<Picture src="itemAdd/category.png" name="级联选择" width="300" />

<Picture src="itemAdd/category2.png" name="最近使用" width="300" />

<Picture src="itemAdd/category3.png" name="搜索" width="300" />

> 类目选选择器写成了一个弹窗式的组件，支持历史记录缓存，模糊查询。

- 这里使用了`ReactNatice`的`Animated`类，整理了一下大体的使用方法，附：[参考链接](/React/Animated.html)

- 由于安卓和IOS的差异，呼起键盘时会出现遮挡输入框的问题，这里对此类问题给出一个通用
<a href='#heightprovider'>处理方法</a>

- [QAP自动关闭键盘](/React/closeKeyBoard.html)

- 类目选择器的查询功能由于淘宝没有提供相应的接口，我们将类目数据存入自己的库中进行查询，和**王炜**对接。
---

## 宝贝描述
<Picture src="itemAdd/desc.png" name="宝贝描述" width="300" />

这个地方没啥好说的，主要难点就是`QNUI`的多行输入框必须固定尺寸或者行数，没法根据文本长度自动撑开，和`pc`端不同的是，又没办法获取`dom`元素的尺寸，所以只能自己计算(有一定的偏差)

- 一个汉字差不多正好是两个字节的长度，一屏为24个汉字的长度

```javascript
 getLength(str) {
    return str.replace(/[\u0391-\uFFE5]/g, "aa").length;
  }
```

- 对`Input`的输入事件进行监听

```javascript
onInput={(e)=>{
    const str = e.value
      const arr = str.split('\n')
      let rows = arr.length
      arr.forEach(s=>{
          const length = self.getLength(s)
          rows+=parseInt(length/48)
        })
       value.rows = rows
       value.v=str
       self.setState({})
}}
```
> 注：这里的`input`不可以使用受控用法，即绑定`value`，这样会导致`setState`时触发重新渲染，会打断`IOS`原生输入法的拼音输入，只绑定`defaultValue`就可以

图片上传采用了和宝贝主图一样的处理方式

---
## [宝贝属性](/Notes/goodsProps.html)

<Picture src="itemAdd/props.png" name="宝贝属性" width="300" />
<Picture src="itemAdd/props2.png" name="枚举属性" width="300" />
<Picture src="itemAdd/props3.png" name="普通度量衡" width="300" />
<Picture src="itemAdd/props4.png" name="时间度量衡" width="300" />

- 调用接口`taobao.itemprops.get`获取该类目下的所有属性，大致分为4类
    1. **枚举属性**，使用选择器进行选择，结果拼入`props`字段
    2. **自定义属性**，用户自定义输入，结果拼入`input_pids` `input_str`字段
    3. **普通度量衡属性**，含有可选单位和属性值，结果拼入`input_pids` `input_str`字段
    4. **时间度量衡属性**，含有单位和属性值或者输入模板，结果拼入`input_pids` `input_str`字段
> [参考链接](https://open.taobao.com/doc.htm?docId=102629&docType=1)


---

## 宝贝规格（销售属性）

<Picture src="itemAdd/sku.png" name="sku" width="300" />
<Picture src="itemAdd/sku2.png" name="普通度量衡" width="300" />
<Picture src="itemAdd/sku3.png" name="备注" width="300" />

1. 这里属性的处理逻辑和宝贝属性差不多，调用接口`taobao.itemprops.get`获取该类目下的销售属性`is_sale_prop===true`

    - 大致分为类
        1. **颜色属性**`is_color_prop===true`,可长按输入备注，也可以进行自定义（暂时不考虑支持）
        2. **普通枚举属性**，只可以选择不可以输入备注
        3. **自定义属性**，用户可自定义输入
        4. **度量衡属性**，需按模板格式填写，可对单位进行选择
        > 其中**颜色属性**和**普通枚举属性**拼入`sku_properties`字段，拼入`props`字段，所有**用户自定义属性**均拼入`sku_properties`字段，拼入`input_custon_cpv`字段，不拼入`props`字段，备注属性拼入`cpv_memo`字段

2. 商品有多个`sku`的情况，比如某商品有`颜色分类`，`长度`和`尺寸`三个销售属性，用户选择了两个颜色（白色，黑色），三个尺码（S,M,L），三个规格（大，中，小），那么该商品的sku总数为`2*3*3=18个`

### 填坑：
-  枚举属性的删除只需要在对应字段里将`pv`对去掉就可以，而自定义属性无论如何都删除不了，后来才发现要将入参`is_replace_sku`置为`true`才可以

--- 

## 运费模板
<Picture src="itemAdd/postFee.png" name="运费模板" width="300" />

**这里复用了林立全的运费模板组件**

> 注：当用户选择运费模板时，自定义的发货地字段无效，将会优先使用运费模板中的发货地

---

## 发布总流程

### 淘宝类目属性获取（规则获取）

#### 可发类目获取`taobao.itemcats.get`

> - 入参：` parent_cid=0`
> - 出参：所有的可供发布的一级类目

叶子类目获取：再次循环调用此接口，入参 `parent_cid= `选择一级类目`id`，获得下一级类目`id`，直至获取叶子类目

**注意：商品需要挂靠在叶子类目发布**

#### 标准商品类目属性获取`taobao.itemprops.get`

> - 入参：cid=1512(手机类目) 其他选填
> - 出参：所有的一级类目属性项和属性值

### 商品发布 `taobao.item.add`

#### 发布步骤

- 步骤1：必填字段准备–基本的信息字段值

```javascript
{
    "location.state":"浙江",
    "location.city":"杭州",
    "num":"999",
    "price":"999",
    "type":"fixed",
    "stuff_status":"new",
    "title":"测试商品请不要拍",
    "desc":"这是一个好商品",
    "cid":"50000671",
}

```

- 步骤2：属性值填写
    > 需拼接字段`props` `input_pids` `input_str` `input_custom_cpv` `sku_properties` 
    
    -  非销售属性拼接
        - 普通属性值枚举
            - 写入`props`字段， 填入`pid:vid` 来自类目属性值获取的结果
        - 普通自定义输入属性值
            - 写入`input_pids` `input_str` 
            - 不写入`props`
    - 销售属性拼接
        - 枚举值的销售属性
            - 写入`props`
            - 写入`sku_properties`
        - 自定义的销售属性
            - 写入`input_custom_cpv`
            - 写入`props`
            - 写入`sku_properties`
    - SKU拼接
        - 需拼接字段
            - `sku_properties`
            - `sku_quantities`
            - `sku_prices`
            - `sku_outer_ids`
            - `sku_barcode`
            
- 步骤3：图片上传
    - 涉及API
        - `taobao.picture.upload`(单张图片上传到图片空间)
        - `taobao.item.img.upload`（商品图片上传）
        - `taobao.item.propimg.upload`（商品属性图片上传）
    

- 步骤4：图片关联
    - 商品主图
        - 使用`taobao.item.add` 接口操作
            > 说明：可传图文件字节 image，也可传图片链接 pic_path ，两个都传，优先使用pic_path
            
    - 商品图片关联（发布成功后可以关联，需要商品id）
        - `taobao.item.joint.img`
    - 属性图片关联（颜色图片，发布成功后可以关联，需要商品id）
        - `taobao.item.joint.propimg`

- 步骤5：邮寄选项

    > 注意：后台建好自己的运费模板，
涉及字段：`postage_id`（运费模板id）

- 步骤6：拼接整个商品发布字段

例：
```javascript
param = {
    approve_status: "onsale",
    cid: 50012413,
    title: "防踢被",
    pic_path: "i3/1810749336/O1CN01m2x81h2IpwB5oXTSS_!!1810749336.png",
    price: "120",
    num: 48,
    desc: "<p>儿童防踢睡袋</p>",
    
    props: "20000:20455;122276315:3267702;20551:105255;20017:4306831;1627207:28321;122216547:3609877",
    input_pids: "13021751",
    input_str: "货号自定义",
    
    sku_outer_ids: ",",
    sku_prices: "120,120",
    sku_properties: "1627207:28321;122216547:3609877,1627207:28321;122216547:-1",
    sku_quantities: "24,24",
    input_custom_cpv: "122216547:-1:小猪佩奇加绒款",
    cpv_memo: "1627207:28321:颜色偏淡",
    
    postage_id: 20589904471,
    item_weight: 3,
    seller_cids: "",
}

```

---

## 附：`controller`部分函数
<a id="pic_space_folder_handler"></a>
```javascript
 /**
   * 图片空间文件夹处理
   */
  pic_space_folder_handler() {
    const self = this
    webSessionIsOk().then(result => {//判断授权是否正常
      if (result.success) {
        const sessionKey = result.sessionKey
        const param = {sessionKey}
        categoryHandler(param).then(result => {
          self.setState({
            pic_category_id: result.data
          })
        })
      }
    })
  }

```

---

## 附：`Component`部分实现
#### `ActionRow`
<a id="actionrow"></a>
```html
export default class ActionRow extends Component {
  constructor(props) {
    super(props)
    this.state={
      warn:false
    }
  }

  render() {
    const left = this.props.left || 0
    const border = style.bottomBorder
    return (
      <View style={[style.actionRowContainer,
        {width: 750 - left},
        this.props.last && border,
        this.props.blank && {marginBottom: '18rem'},]}>
        <Text style={style.required}>{this.props.required?'*':''}</Text>
        <View style={[style.actionRow,
          !this.props.last && border,
          this.props.style]}>
          <View style={{
            flexDirection: 'row',
            justifyContent: 'space-between',
            alignItem: 'center',
            width: 750 - left - 38
          }}>
            <View style={[style.labelContainer,this.props.labelStyle]}>
              <Text style={[style.labelText,this.props.labelStyle]}>{this.props.label}</Text>
            </View>
            {this.renderAction()}
          </View>
          {this.state.warn&&
          <View style={style.warnContainer}><Text style={style.warning}>{this.props.warn}</Text></View>}
        </View>
      </View>
    )
  }

  renderAction() {
    if (this.props.type === 'input') {
      if (this.props.multi) {
        return (
          <Input style={[style.multiInput, QN.os.ios && {paddingLeft: '15rem'}]}
                 multiple={true}
                 ref={'multiple'}
                 id="multiple"
                 placeholder={'请输入'}
                 defaultValue={this.props.value}
                 onInput={this.onInput.bind(this)}
                 rows={3}
          />
        )
      } else {
        if(this.props.disabled){
          return(
            <View onClick={()=>{Toast.toast('商品总库存不可编辑')}} style={style.disabled}>
                <Text style={style.labelText}>{this.props.value||0}</Text>
            </View>
          )
        }else{
          return(
            <Input style={style.input}
                   disabled={this.props.disabled}
                   htmlType={this.props.htmlType}
                   placeholder={this.props.placeholder || '请输入'}
                   value={this.props.value}
                   onInput={this.onInput.bind(this)}
            />
            )
        }
      }
    } else {
      return (
        <TouchableHighlight style={style.selectContainer} onPress={this.props.onPress}>
          <Text style={[style.placeholder,
            this.props.value && {color: '#333333'},
            this.props.disabled && {marginRight: '50rem'}]}>
            {this.props.value || this.props.placeholder || '请选择'}
          </Text>
          {!this.props.disabled && <Icon name={'arrowRight'} style={style.arrowRight}/>}
        </TouchableHighlight>
      )
    }
  }
  onInput(e){
    if(this.props.warnReg){
          this.setState({
            warn:!this.props.warnReg(e.value)
          })
      this.props.onInput(e)
    }else{
      this.props.onInput(e)
    }
  }
}
```

#### `HeightProvider`
<a id="heightProvider"></a>
```javascript
import QN from 'QAP-SDK'
let componentMap = new Map()//注册组件实例
let keyBoardHeight=0
if (!QN.os.ios) {//安卓端处理
  QN.on('Global.KeyboardWillShow', ({height}) => {
    keyBoardHeight=height
    setState()
  })
  QN.on('Global.KeyboardWillHide', () => {
    keyBoardHeight=0
    setState()
  })
}
export function register(component){//组件注册，如果组件需要进行高度调整，将组件实例添加到map，在高度变化时返回键盘高度
  if(component.name&&component.instance){
    componentMap.set(component.name,component.instance)
  }
  return keyBoardHeight
}
export function logout(component){//组件注销
  componentMap.has(component.name)&&componentMap.delete(component.name)
}
//在高度变化时返回键盘高度
function setState(){
  if(componentMap.size>0){
    for(let v of componentMap.values()){
      v.setState({
        keyBoardHeight:keyBoardHeight
      })
    }
  }
}
```
##### 使用方法：
- 在组件构建完毕后进行注册

```javascript
let keyBoardHeight = register(CategorySelection)
this.state = {
      keyBoardHeight: keyBoardHeight
}
```
> 获取初始键盘高度，将其放入组件`state`中

- 在`render`方法中动态为组件设置高度
```javascript
const {height, width} = window.screen,//屏幕像素
 pureHeight = height / (width / 750) //屏幕真实高度（rem）
 body_height = pureHeight - this.state.keyBoardHeight//组件高度为真实高度减去键盘高度

 return <View  style={[style.dialogWrap, {height: height}]}>
```
这样在呼出键盘时，由于我们已经将组件实例注册到`heightProvider`中，所以会自动调用`setState`方法触发重新渲染，更新键盘高度






