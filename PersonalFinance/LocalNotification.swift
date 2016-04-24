//
//  LocalNotification.swift
//  LocalNotificationTest
//
//  Created by 子叶 on 16/4/22.
//  Copyright © 2016年 王焕强. All rights reserved.
//

import UIKit

class LocalNotification: NSObject {
    
    static let sharedInstance = LocalNotification()
    private let prepareLocalNotication = PrepareLocalNotification.sharedInstance
    private let baseInfo = BaseInfo.sharedBaseInfo
    
    
    private override init() {
        super.init()
    }
    
    // 月初提醒本月预算
    func createShowMonthBudgetNotification() {
        let budget: Double = baseInfo.gainMonthBudget().doubleValue        
        // 设置触发时间为下个月1号8点
        let notification =  prepareLocalNotication.createLocalNotification("您的本月预算为：\(budget.convertToStrWithTwoFractionDigits())", fireDate: NSDate().firstDayWithNextMonth(8))
        
        // 设置触发周期为：每月
        notification.repeatInterval = .Month
        // 设置 通知
        prepareLocalNotication.scheduleLocalNotification(notification)
    }
    
    // 每周一提醒上周的消费情况
    func createShowLastWeekExpenseNotification() {
        // 设置触发时间为下个星期第一天的8店
        let notification =  prepareLocalNotication.createLocalNotification("您上周的消费报表已经生成了，快来查看吧！", fireDate: NSDate().firstDayWithNextWeek(8))
        
        // 设置触发周期为：每周
        notification.repeatInterval = .WeekOfYear
        
        // 设置 通知
        prepareLocalNotication.scheduleLocalNotification(notification)
    }
    
    
    
    
    
    /*
     当用户每月消费了每月预算的 50%，80%的时候分别给出提示 
        示例： 警告：您已经消费了本月预算的50%，共500元，接下来您每天还可以使用XX元
     有通知框有两个选项：
     * 忽视
     * 查看：点击后直接跳转至当月消费情况列表
     */
    func createPercentInMonthBudgetNotification(percent: Double) {
        
        let fireDate = NSDate(timeInterval: 10.0, sinceDate: NSDate())
        
        let dayExpense = (baseInfo.gainMonthBudget().doubleValue - baseInfo.monthExpense()) / Double(fireDate.monthDays - fireDate.day)
        
        let bodyInfo = "警告：您已经消费了本月预算的\(percent.convertToStrWithTwoFractionDigits())%，共 \(baseInfo.monthExpense().convertToStrWithTwoFractionDigits())元，接下来您每天还可以使用\(dayExpense.convertToStrWithTwoFractionDigits())元"
        
        let workAction = NotificationAction(name: "立即查看", id: "PercentInMonthBudgetWorkAction")
        let relaxAction = NotificationAction(name: "忽略", id: "PercentInMonthBudgetRelaxAction")
        
        // 创建一个通知
        let notification =  prepareLocalNotication.createLocalNotificationWithTwoAction(bodyInfo, fireDate: fireDate, categoryID: "CategoryNotificationWithPercentInMonthBudget", workAction: workAction, relaxAction: relaxAction)
        
        // 启动 通知
        prepareLocalNotication.scheduleLocalNotification(notification)
    }
    
    
    /*
     在每月最后一天的时候，对比 当月 和 上一个月 的消费情况，
     在通知框里显示消费总额对比情况（如“您本月仅消费了 800 元，比上月消费减少了200元，成为一名省钱小能手！”）
     * 忽视
     * 查看详情：点击后跳转至页面： 显示这两个月的消费情况（雷达图）
     */
    
}
