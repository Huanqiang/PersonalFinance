//
//  BaseInfo.swift
//  PersonalFinance
//
//  Created by ziye on 16/1/30.
//  Copyright © 2016年 王焕强. All rights reserved.
//

import UIKit

private let sharedInstance = BaseInfo()

class BaseInfo: NSObject {
    // 设置 单例
    class var sharedBaseInfo: BaseInfo {
        return sharedInstance
    }
    
    private let userDefault: NSUserDefaults = {
        return NSUserDefaults.standardUserDefaults()
    }()
    
    
    // MARK: - 每月预算
    func saveMonthBudget(value: NSNumber) {
        self.saveMoneyInfo(value.doubleValue, key: "MonthBudget")
    }
    
    func monthBudget() ->Double {
        return self.getMoneyInfo("MonthBudget")
    }
    
    // MARK: - 最新消费
    func newExpense() ->Double {
        guard let consume: SingleConsume = SingleConsume.fetchLastConsumeRecord() else {
            return 0.0
        }
        
        return consume.money!.doubleValue
    }
    
    // MARK: - 每周支出
    func weekExpense() ->Double {
        return SingleConsume.fetchExpensesInThisWeek(NSDate())
    }
    
    // MARK: - 每月支出
    func monthExpense() ->Double {
        return SingleConsume.fetchExpensesInThisMonth(NSDate())
    }
    
    // MARK: - 每日支出
    func dayExpense() ->Double {
        return SingleConsume.fetchExpensesInThisDay(NSDate())
    }
    
    
    
    // MARK: - 当第一次进入应用的时候初始化各项基本数据
    /**
     当第一次进入应用的时候初始化各项基本数据
     */
    func initDataWhenFirstUse() {
        self.saveMonthBudget(0.0)
        self.saveTime(NSDate())
    }
    
    // MARK: 是否用过引导页的标示
    func saveOnBoardSymbol() {
        self.userDefault.setBool(true, forKey: "HasOnborad")
        self.userDefault.synchronize()
    }
    
    func gainOnBoardSymbol() ->Bool {
        return self.userDefault.boolForKey("HasOnborad")
    }
}

// MARK: - 各项与时间相关的操作
extension BaseInfo {
    func isCurrentMonth(date: NSDate) ->Bool {
        if date.isInThisMonth(self.gainTime()) {
            return true
        }else {
            return false
        }
    }
    
    func isToday(date: NSDate) ->Bool {
        if date.isThisDay(self.gainTime()) {
            return true
        }else {
            return false
        }
    }
    
    private func isNewDay(date: NSDate) ->Bool {
        let tomorrow = self.gainTime().dayEnd()
        
        if tomorrow.isLaterWithNewTime(date) {
            return true
        }
        return false
    }
    
    func saveTime(date: NSDate) {
        self.saveTimeInfo(date, key: "today")
    }
    
    private func gainTime() ->NSDate {
        return self.getTimeInfo("today")
    }
    
}


// MARK: - NSUserDefault 操作
extension BaseInfo {
    private func saveMoneyInfo(value: Double, key: String) {
        self.userDefault.setDouble(value, forKey: key)
        self.userDefault.synchronize()
    }
    
    private func getMoneyInfo(key: String) ->Double {
        return self.userDefault.doubleForKey(key)
    }
    
    private func saveTimeInfo(value: NSDate, key: String) {
        self.userDefault.setObject(value, forKey: key)
        self.userDefault.synchronize()
    }
    
    private func getTimeInfo(key: String) ->NSDate {
        return self.userDefault.objectForKey(key) as! NSDate
    }
}
