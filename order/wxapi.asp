<%
	@codepage = 65001
%>
<!--#include file="conn.asp"-->
<!--#include file="../core/WeChatPay.asp"-->
<%
	set pay = new WeChatPay
	
	'设置支付参数，也可以直接修改 WeChatPay.asp
	'pay.AppID       = "AppID"
	'pay.AppSecret   = "App密码"
	'pay.MchID       = "商户ID"
	'pay.MchKey      = "商户密码"
	'pay.notifyUrl   = ""	'notifyUrl不指定，则会自动根据当前环境判断
	
	
	orderNo = Request.QueryString("order_no")
	
	Select Case Request.QueryString("payType")
		Case "ajax"
			Response.ContentType = "text/javascript;charset=utf-8"
			'检查订单信息
			if GetOrderInfo(OrderRs, 1, orderNo) then
				o_title = OrderRs("o_title")
				o_body = OrderRs("o_body")
				o_money = OrderRs("o_money")
				OrderRs.close
				result = pay.Pay(orderNo, o_title, o_body, o_money)
				if left(result, 15) = "weixin://wxpay/" then
					response.write "{""status"":true, ""payUrl"":""" & result & """}"
				else
					response.write "{""status"":false, ""errMsg"":""" & result & """}"
				end if
			else
				response.write "{""status"":false, ""errMsg"":""订单不存在""}"
			end if
		Case "check"
			Response.ContentType = "text/javascript;charset=utf-8"
			'检查订单状态
			if GetOrderInfo(OrderRs, 2, orderNo) then
				OrderRs.close
				response.write "{""status"":true}"
			else
				response.write "{""status"":false}"
			end if
		Case Else
			'微信返回结果
			set result = pay.GetNotify()
			if result.item("status") = false then
				response.write result.item("message")
			else
				out_trade_no =  result.item("out_trade_no")
				total_fee =  result.item("total_fee")
				trade_no =  result.item("trade_no")
				if GetOrderInfo(OrderRs, 1, out_trade_no) then
					'调整订单状态为支付完成
					OrderRs("o_trade_no") = trade_no
					OrderRs("o_paytime") = now()
					OrderRs("o_status") = 2
					OrderRs.update
					OrderRs.close
					response.write "<return_code>SUCCESS</return_code><return_msg>OK</return_msg>"
				else
					'没有等待确认的订单，一般修改为成功，不让微信继续通知
					response.write "<return_code>SUCCESS</return_code><return_msg>OK</return_msg>"
				end if
			end if
			
			'记录日志
			set fso = server.createobject("Scripting.FileSystemObject")
			set fto = fso.createtextfile(server.mappath("/order/log/" & resultType & "_log_" & out_trade_no & "_" & timer() & ".txt"))
			fto.write(now() & vbCrlf & request.querystring & vbCrlf & request.form)
			fto.close
			set fso = nothing
			
	End Select
	
	Conn.Close
	
	'=============================================================================================
	function GetOrderInfo(byref orderRecordSet, byval orderStatus, byval tradeNo)
		set orderRecordSet = Server.CreateObject("Adodb.RecordSet")
		orderRecordSet.open "select * from orderinfo where o_status=" & orderStatus & " and o_order_no='" & orderNo & "'", Conn, 3, 2
		if orderRecordSet.eof then
			orderRecordSet.close
			GetOrderInfo = false
		else
			GetOrderInfo = true
		end if
	end function
%>