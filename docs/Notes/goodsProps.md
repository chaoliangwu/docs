## 介绍
淘宝不同的宝贝类目商品属性不同，他们在本质上分为两类：
- 销售属性（sku）
- 商品属性

这里我们只讨论其中的商品属性。

## 属性
通过`taobao.itemprops.get`获得

入参：
- `cid` 叶子类目ID
- `pid` 属性id (取类目属性时，传pid，不用同时传PID和parent_pid)
- `parent_pid`父属性ID
- `child_path`类目子属性路径,由该子属性上层的类目属性和类目属性值组成,格式`pid:vid;pid:vid`取类目子属性需要传`child_path` `cid`
### 普通字段

名称 | 描述
---|---
 pid  | 属性id
 parent_pid  | 父属性ID
 name |属性名
 is_key_prop |是否关键属性
 is_sale_prop |是否销售属性
 is_color_prop |是否颜色属性
 is_enum_prop |是否是可枚举属性
 is_input_prop | 在`is_enum_prop`是`true`的前提下，是否是卖家可以自行输入的属性（注：如果`is_enum_prop`返回`false`，该参数统一返回`false`）
 must |是否为必选属性
 multi |是否可以多选
 child_template |子属性的模板
 prop_values | [子属性列表](/Notes/goodsProps.html#子属性列表)
 is_material |是否是材质属性项
 material_do |[材质属性信息](/Notes/goodsProps.html#材质属性信息)
is_taosir|是否度量衡属性项
taosir_do|[度量衡属性信息](/Notes/goodsProps.html#度量衡属性信息)
        
### 子属性列表
<table>
<thead>
<tr>
    <td colspan=2>名称</td>
    <td>描述</td>
</tr>
</thead>

<tr>
    <td rowspan=5>prop_values</td>
</tr>
<tr>
    <td >pid</td>
    <td>属性ID</td>
</tr>
<tr>
   <td >vid</td>
       <td>属性值ID</td>
</tr>
<tr>
   <td >name</td>
       <td>属性值</td>
</tr>
<tr>
   <td >is_parent</td>
       <td>是否为父类目属性</td>
</tr>
</table>

### 材质属性信息
<table>
<thead>
<tr>
    <td colspan=3>名称</td>
    <td>描述</td>
</tr>
</thead>
<tr>
    <td rowspan=3>material_do</td>
     <td rowspan=3>materials</td>
</tr>
<tr>
    <td>name</td>
    <td>材质值名称</td>
</tr>
<tr>
    <td>need_content_number</td>
    <td>是否需要填写含量值</td>
</tr>
</table>

### 度量衡属性信息
<table>
<thead>
<tr>
    <td colspan=3>名称</td>
    <td>描述</td>
</tr>
</thead>
<tr>
    <td rowspan=12>taosir_do</td>
</tr>
<tr>
    <td colspan=2>precision</td>
    <td>数值小数点精度</td>
</tr>
<tr>
    <td colspan=2>type</td>
    <td>时间类型：0表示非时间，1表示时间点，2表示时间范围</td>
</tr>
<tr>
    <td rowspan=3>std_unit_list</td>
</tr>
<tr>
    <td >attr_key</td>
    <td rowspan=2>卖家可选单位List<单位id，单位名></td>
</tr>
<tr>
    <td >attr_value</td>
</tr>
<tr>
    <td rowspan=6>expr_el_list</td>
</tr>
<tr>
    <td>text</td>
    <td>显示文本</td>
</tr>
<tr>
    <td >is_show_label</td>
    <td>是否只用于显示的文本元素</td>
</tr>
<tr>
    <td >is_label</td>
    <td>是否文本元素，用于显示也用于组装value_name，比如:操作符</td>
</tr>
<tr>
    <td >is_input</td>
    <td>是否输入框</td>
</tr>
<tr>
    <td >type</td>
    <td>0类型为label元素，只用于展示，不用于组装value_name。1类型为label元素，用于展示，用于组装value_name。
    2类型为输入框元素，主要用于卖家输入数据。卖家填写完后需要重新设置该元素的文本数据。</td>
</tr>
</table>

## 属性组装
首先过滤掉销售属性 `is_sale_prop===false`

初始化一个默认商品，需要组装三个字段
```jsx harmony
item:{
  props:'',
  input_pids:'',
  input_str:''
}
```

### 枚举属性
`is_enum_prop===true`

`is_input_prop===false`

`prop_values!==null`

枚举属性的处理相对简单，遍历`prop_values`列表，将用户选择值拼入商品`props`字段，格式为`pid:vid`

- 用户选择`包装方式:散装`
    - 包装方式pid为`30000`
    - 散装子属性vid为`129808`
    
此时商品属性为
```jsx harmony
item:{
  props:'30000:129808',
  input_pids:'',
  input_str:''
}
```

### 自定义属性
`is_enum_prop===true`

`is_input_prop===true`

`prop_values===null`

将`pid`拼入`input_pids`，输入值拼入`input_str`

- 用户输入`货号:2019年夏款`
    - 货号pid为`21394`
此时商品属性为
```jsx harmony
item:{
  props:'30000:129808',
  input_pids:'21394',
  input_str:'2019年夏款'
}
```
### 枚举&&自定义
`is_enum_prop===true`

`is_input_prop===true`

`prop_values!==null`

有些属性即支持选择也支持自定义输入，此时根据用户操作做判断。如果是选择，那么按枚举属性处理，如果是输入，按自定义输入处理。

### 子属性
#### 作为单独属性
在枚举属性的前提下，如果用户选择的选项`is_parent`为`true`，那么该属性下还有附加子属性。

用户选择`产地:中国大陆` 
- 产地pid为`21299`
- 中国大陆的属性为
```jsx harmony
{
  vid:27772,
  name:'中国大陆',
  is_parent:true
}
```

此时，再次调用接口`taobao.itemprops.get`，入参添加`child_path`为`21299:27772` ，可获得产地子属性`省份`，子属性作为单独属性重新做处理。如果子属性选项依旧含有子属性，以此类推直至最末节点。

用户最终选择`产地:中国大陆` `省份:山东省` `城市:临沂市`
- 产地pid为`21299` 中国大陆vid为`27772`
- 子属性省份pid为`24557` 山东省vid为`254221`
- 叶子属性城市pid为`31778` 临沂市vid为`47653222`

此时商品属性为
```jsx harmony
item:{
  props:'30000:129808,21299:27772,24557:254221,31778:47653222',
  input_pids:'21394',
  input_str:'2019年夏款'
}
```
#### 作为附属属性
有些枚举属性的子选项没有`is_parent===true`，但是该属性含有`child_template`字段，那么该属性的子属性是作为附属属性存在，拼接时和父属性共用一个字段。

用户选择`品牌:阿迪达斯`
- 品牌pid为`20000`
- 品牌child_template为`系列;型号` 

**情景1** 品牌为自定义输入值
- `系列` `型号`将作为品牌的必填**自定义输入**子属性（是否必填跟随品牌判断）
- 用户输入`品牌` `系列` `型号`三个字段，输入值`阿迪达斯` `三叶草` `跑步鞋系列`

需拼接字段为
```jsx harmony
input_pids:'20000'
input_str:'阿迪达斯;系列;三叶草;型号;跑步鞋'
```
::: tip input_str结构
`父属性值;一级子属性名;一级子属性值;二级子属性名;二级子属性值,....`以分号分隔
:::
   
此时商品属性为
```jsx harmony
item:{
  props:'30000:129808,21299:27772,24557:254221,31778:47653222',
  input_pids:'21394,20000',
  input_str:'2019年夏款,阿迪达斯;系列;三叶草;型号;跑步鞋'
}
```
**情景2** 品牌为枚举选择值
- **情景2.1** 用户选择的值`is_parent===true`

这种情况下，`is_parent===true`优先级高于`child_template`，即按照上述`作为单独属性`进行处理，**忽略`child_template`字段**。
- **情景2.2** 用户选择的值没有`is_parent`字段

用户选择`品牌:耐克`,该子属性`is_parent===false`
- 品牌pid为`20000`
- 耐克vid为`44335`

那么此时`系列` `型号`将作为品牌的必填**自定义输入**子属性（是否必填跟随品牌判断）
- 用户输入`系列` `型号`两个字段，输入值`乔丹系列` `airjordan`

需拼接字段为
```jsx harmony
props:'20000:44335'
input_pids:'20000'
input_str:'耐克;系列;乔丹系列;型号;airjordan'
```

::: warning 注意
`品牌:耐克`需要在`props`和`input_pids` `input_str`同时拼入
:::
此时商品属性为
```jsx harmony
item:{
  props:'30000:129808,21299:27772,24557:254221,31778:47653222,20000:44335',
  input_pids:'21394,20000',
  input_str:'2019年夏款,耐克;系列;乔丹系列;型号;airjordan'
}
```

### 材质属性
`is_material===true`

属性中的`materials.item_materia_value_d_o`为可选材质列表，用户可选一种或多种材质。

当材质`need_content_number===true`时，需要用户输入改材质含量。多种材质成分总和需为100%。

用户选择三组材质信息分别为`彩棉` `羊毛` `棉`，其中`羊毛`和`棉`分别输入含量值`80%` `20%`
- 材质pid为`149422948`
需拼接字段为
```jsx harmony
input_pids:'149422948'
input_str:'彩棉 羊毛80% 棉20%'
```
::: warning 注意
材质值一律按照自定义属性进行拼接,用空格隔开，成分含量跟在材质值后
:::

此时商品属性为
```jsx harmony
item:{
  props:'30000:129808,21299:27772,24557:254221,31778:47653222,20000:44335',
  input_pids:'21394,20000,149422948',
  input_str:'2019年夏款,耐克;系列;乔丹系列;型号;airjordan,彩棉 羊毛80% 棉20%'
}
```

### 度量衡属性
`is_taosir===true`

#### 单位处理
度量衡属性都是带单位的，有些度量衡只有一个单位，有些度量衡需要用户在单位列表中选择一个单位，该单位参与最后的组装。

遍历单位列表供用户选择`taosir_do.std_unit_list.std_unit`

#### 输入值校验

度量衡输入为纯数字,需获取`taosir_do.precision`对输入值进行校验

`precision`
值|精度
---|---
0|整数
1  |保留一位小数
2|保留两位小数

#### 获取用户输入
##### 度量衡不含输入模板
    
这种情况下直接获取用户输入值并进行校验，带单位拼入`input_str`字段

用户输入`净含量`属性值为`150`，获取到的单位为`g` `kg`，用户选择`g`

净含量pid为`25479856`

需拼接字段为
```jsx harmony
input_pids:'25479856',
input_str:'150g'
```

##### 度量衡含有输入模板

`taosir_do.expr_el_list.expr_el`

名称|描述
---|---
text|显示文本
is_show_label|是否只用于显示（不参与组装）
is_label|是否文本元素，用于显示也用于组装
is_input|是否输入框

用户选择`尺寸`属性,
- 尺寸pid为`3764420`
输入模板为
```jsx harmony
[
  {
    text:'长',
    is_show_label:true,
    is_label:false,
    is_input:false
  },
  {
    is_show_label:false,
    is_label:false,
    is_input:true
  },
  {
    text:'x',
    is_show_label:false,
    is_label:true,
    is_input:false
  },
  {
    text:'宽',
     is_show_label:true,
     is_label:false,
     is_input:false
  },
  {
    is_show_label:false,
    is_label:false,
    is_input:true
  },
]
```

给用户展示的输入框应为：长 [输入框] x 宽 [输入框]

用户输入`长`120，`宽`30 ,选择单位为`cm`

那么对模板进行组装
- 第一个属性`is_show_label===true`，说明`长`不参与组装，略过
- 第二个属性`is_input===true`是`输入框`，将用户输入值120拼入,拼入后`input_str`为`120`
- 第三个属性`is_label===true`,说明`x`参与组装,拼入后`input_str`为`120x`
- 第四个属性`is_label===true`,说明`宽`不参与组装，略过
- 第五个属性`is_input===true`是`输入框`，将用户输入值30拼入,拼入后`input_str`为`120x30`

遍历结束，拼入用户所选单位`cm`。此时，需拼接字段为
```jsx harmony
input_pids:'3764420',
input_str:'120x30cm'
```
将净含量，尺寸拼入，此时商品属性为
```jsx harmony
item:{
  props:'30000:129808,21299:27772,24557:254221,31778:47653222,20000:44335',
  input_pids:'21394,20000,149422948,25479856,3764420',
  input_str:'2019年夏款,耐克;系列;乔丹系列;型号;airjordan,彩棉 羊毛80% 棉20%,150g,120x30cm'
}
```

## 属性解析

待完成

