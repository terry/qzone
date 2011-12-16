require 'rubygems'
require 'json'
require 'net/http'
require 'uri'

# 错误代码定义
# 参数为空
PYO_ERROR_REQUIRED_PARAMETER_EMPTY = 2001
# 参数格式果物
PYO_ERROR_REQUIRED_PARAMETER_INVALID = 2002
# 返回包格式错误
PYO_ERROR_RESPONSE_DATA_INVALID = 2003
# 网络错误, 偏移量3000, 详见 http://curl.haxx.se/libcurl/c/libcurl-errors.html
PYO_ERROR_CURL = 3000


class QQPengyou
  VERSION = '1.0.0'

  # Pengyou OpenAPI 服务器的域名
  # 默认：http://openapi.pengyou.qq.com
  attr :server_name

  # 构造函数
  # 参数:
  #   - app_id : 应用的唯一ID
  #   - app_key : 应用的密钥，用于验证应用的合法性
  #   - app_name : 应用的英文名(唯一)
  def initialize(app_id,app_key,app_name)
    @server_name = '119.147.75.204'
    @app_id = app_id
    @app_key = app_key
    @app_name = app_name
  end

  class << self
    def valid_open_id?(open_id)
      return true if /^[0-9a-fA-F]{32}$/.match(open_id)
      false
    end
  end


  def api(method,options = {})
    # 验证信息
    if options[:openid] == nil or options[:openid] == ''
      return {:ret => PYO_ERROR_REQUIRED_PARAMETER_EMPTY, :msg => 'openid is empty'}
    end
    if options[:openkey] == nil or options[:openkey] == ''
      return {:ret => PYO_ERROR_REQUIRED_PARAMETER_EMPTY, :msg => 'openkey is empty'}
    end
    if not QQPengyou.valid_open_id?(options[:openid])
      return {:ret => PYO_ERROR_REQUIRED_PARAMETER_INVALID, :msg => 'openid is invalid'}
    end

    # 添加一些参数
    options[:appid] = @app_id
    options[:appkey] = @app_key
    options[:ref] = @app_name

    # 得到 OpenAPI 的地址
    path = get_api_path(method)

    return make_request(path,options)
  end


  private
  # 执行一个 HTTP POST 请求, 返回结果数组。可能发生cURL错误
  # 参数:
  #   - path : 执行请求的路径
  #   - options : 表单参数
  def make_request(path,options = {})
    http = Net::HTTP.new("#{@server_name}")
    query_params = options.collect { |v| v.join("=") }.join("&")    
    req = http.request_post(path,query_params,{'User Agent' => 'pengyou-php-1.1'})
    begin
      #
    rescue Exception => e 
      # cURL 网络错误, 返回错误码为 cURL 错误码加偏移量
      # 详见 http://curl.haxx.se/libcurl/c/libcurl-errors.html
      return {:ret => PYO_ERROR_CURL, :msg => e.inspect }
    end
    
    # 远程返回的不是 json 格式, 说明返回包有问题
    result_json = JSON.parse(req.body)
    if result_json == {}
      return {:ret => PYO_ERROR_RESPONSE_DATA_INVALID, :msg => result}
    end
        
    return result_json
  end
  
  
  # 根据要调用的方法返回 API URL  
  def get_api_path(method)
    "/cgi-bin/xyoapp/#{method}.cgi"
  end
  
  public
  # 返回当前登录用户信息
  # return hash
	#		- ret : 返回码 (0:正确返回, [1000,~]错误)
	#		- nickname : 昵称
	#		- gender : 性别
	#		- province : 省
	#		- city : 市
	#		- figureurl : 头像url
	#		- is_vip : 是否黄钻用户 (true|false)
	#		- is_year_vip : 是否年费黄钻(如果is_vip为false, 那is_year_vip一定是false)
  #   - vip_level : 黄钻等级(如果是黄钻用户才返回此字段)      
  def get_user_info(openid,openkey)
    return api('/user/info',:openid => openid, :openkey => openkey)
  end
  
  # 验证是否好友(验证 fopenid 是否是 openid 的好友)
  # 参数:
  #    openid openid
	#    openkey openkey
	#    options Hash 值
	#    		fopenid  待验证用户的openid
  # 返回值(Hash):
  #    - ret  : 返回码 (0:正确返回, [1000,~]错误)
  #    - isFriend  : 是否为好友(0:不是好友; 1:是好友; 2:是同班同学)
  def is_friend(openid,openkey, options = {})
    if not QQPengyou.valid_open_id?(options[:fopenid])
      return {:ret => PYO_ERROR_REQUIRED_PARAMETER_INVALID, :msg => 'fopenid is invalid' }
    end
    
    return api('/relation/is_friend', 
                :openid => openid, 
                :openkey => openkey, 
                :fopenid => options[:fopenid])
  end
  
  # 获取好友列表
  # 参数 options 说明:
  # 	:infoed  是否需要好友的详细信息(0:不需要;1:需要)
	#		:apped  对此应用的安装情况(-1:没有安装;1:安装了的;0:所有好友)
	#		:page  获取对应页码的好友列表，从1开始算起，每页是100个好友。(不传或者0：返回所有好友;>=1，返回对应页码的好友信息)
  # 返回值:
  #  @return array 好友关系链的数组
	#		- ret : 返回码 (0:正确返回; (0,1000):部分数据获取错误,相当于容错的返回; [1000,~]错误)
	#		- items : array 用户信息
	#		- openid : 好友QQ号码转化得到的id
	#		- nickname : 昵称(infoed==1时返回)
	#		- gender : 性别(infoed==1时返回)
	#		- figureurl : 头像url(infoed==1时返回)
  def get_friend_list(openid,openkey, options = {})
    infoed = options[:infoed] || 0
    apped = options[:apped] || 1
    page = options[:page] || 0
    return api('/relation/friends',
        :openid => openid,
        :openkey => openkey,
        :infoed => infoed,
        :apped => apped,
        :page => page)
  end
  
  # 批量获取用户详细信息
  # 参数:
  #   - :fopenids : Array 需要获取数据的openid列表
  # 返回 HASH 好友详细信息数组:
	#		- ret : 返回码 (0:正确返回; (0,1000):部分数据获取错误,相当于容错的返回; [1000,~]错误)
	#		- items : array 用户信息
	#		- openid : 好友的 OPENID
  #   - nickname :昵称
	#		- gender : 性别
	#		- figureurl : 头像url
	#		- is_vip : 是否黄钻 (true:黄钻; false:普通用户)
	#		- is_year_vip : 是否年费黄钻 (is_vip为true才显示)
	#		- vip_level : 黄钻等级 (is_vip为true才显示)
  def get_multi_info(openid, openkey, options = {})
    fopenids = options[:fopenids]
    if fopenids == nil or fopenids.class != [].class
      return { :ret => PYO_ERROR_REQUIRED_PARAMETER_EMPTY, :msg => 'fopenids is empty or not a Array type.' }
    end
    
    return api('/user/multi_info',
                :openid => openid,
                :openkey => openkey,
                :fopenids => fopenids.join("_"))
  end
  
  # 验证登录用户是否安装了应用
  # 返回值 hash:
  #   - ret : 返回码 (0:正确返回, [1000,~]错误)
	#		- setuped : 是否安装(0:没有安装;1:安装)
  def setuped?(openid, openkey)
    return api('/user/is_setuped',
                :openid => openid,
                :openkey => openkey)
  end
  
  # 判断用户是否为黄钻
  # 返回值 hash:
  #   - ret : 返回码 (0:正确返回, [1000,~]错误)
  #		- is_vip : 是否黄钻 (true:黄钻; false:普通用户)   
  def vip?(openid, openkey)
    return api('/pay/is_vip',
                :openid => openid,
                :openkey => openkey)
  end
  
  # 获取好友的签名信息
  # 参数:
  #   - openid
  #   - openkey
  #   - :fopenids : Array 需要获取数据的openid列表(一次最多20个)
  # 返回值 HASH:
  #   - ret : 返回码 (0:正确返回; (0,1000):部分数据获取错误,相当于容错的返回; [1000,~]错误)
	#		- items : Array 用户信息
	#		- openid: 好友QQ号码转化得到的id
	#		- content: 好友的校友心情内容
  def get_emotion(openid, openkey, options = {})
    fopenids = options[:fopenids]
    if fopenids == nil or fopenids.class != [].class
      return { :ret => PYO_ERROR_REQUIRED_PARAMETER_EMPTY, :msg => 'fopenids is empty or not a Array type.' }
    end
    
    
    return api('/user/emotion',
                :openid => openid,
                :openkey => openkey,
                :fopenids => fopenids.join("_"))
  end
  
end
