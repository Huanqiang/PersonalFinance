//
//  ChartViewController.swift
//  PersonalFinance
//
//  Created by 子叶 on 16/4/7.
//  Copyright © 2016年 王焕强. All rights reserved.
//

import UIKit
import Charts
import DZNEmptyDataSet

class ChartViewController: UIViewController {

    // UIScrollView 约束
    @IBOutlet weak var scrollViewWidth: NSLayoutConstraint!
    @IBOutlet weak var secondViewLeading: NSLayoutConstraint!
    
    // MARK: - 实例变量
    
    // 普通实例变量
    let chartVM: ChartViewModel = ChartViewModel()
    
    
    // 控制视图 实例变量
    @IBOutlet weak var categoryTableView: UITableView!    
    @IBOutlet weak var pageControl: UIPageControl!
    
    // 饼图部分
    @IBOutlet weak var categoryCurrentTime: UILabel!
    @IBOutlet weak var categoryArrowLeft: UIButton!
    @IBOutlet weak var categoryArrowRight: UIButton!
    @IBOutlet weak var categoryChartView: PieChartView!
    
    // 走势图部分：以一个月的四周作为走势图
    @IBOutlet weak var sevenDaysChartView: BarChartView!
    
    // 以一年的12个月作为走势图
    @IBOutlet weak var thirdWeeksChartView: LineChartView!
    
    
    let screenWidth = CGRectGetWidth(UIScreen.mainScreen().bounds)
    
    
    // 设置 UIScrollView 约束
    override func updateViewConstraints() {
        super.updateViewConstraints()
        
        self.scrollViewWidth.constant = screenWidth * 2
        self.secondViewLeading.constant = screenWidth
        
        categoryChartView.delegate = self
        sevenDaysChartView.delegate = self
        thirdWeeksChartView.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.title = "报表"
        
        // 去除 tableView 多余的分割线
        self.categoryTableView.tableFooterView = UIView()
    }
    
    override func viewWillAppear(animated: Bool) {
        // 创建环形图
        self.preparePieChartWithCategory(self.chartVM.currentMonthWithCategory!)
        
        // 创建七天消费柱状图
        self.prepareSevenDaysBarChart()
        
        // 创建三周消费走势图
        self.prepareThirdWeeksTrendChart()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    // MARK: - 按钮功能
    @IBAction func clickCategoryArrowLeft(sender: AnyObject) {
        let newDate = self.chartVM.gainDateForPreMonthWithCategory()
        self.chartVM.setConsumeCategoryArrWithDate(newDate)
        self.preparePieChartWithCategory(newDate)
    }

    @IBAction func clickCategoryArrowRight(sender: AnyObject) {
        let newDate = self.chartVM.gainDateForNextMonthWithCategory()
        self.chartVM.setConsumeCategoryArrWithDate(newDate)
        self.preparePieChartWithCategory(newDate)
    }
    
    
    // MARK: - 创建环形图
    // 配置 创建环形图操作
    func preparePieChartWithCategory(date: NSDate) {
        // 创建环形图
        if self.chartVM.gainTotalExpense() == 0 {
            createPieChart([], values: [], money: self.chartVM.gainTotalExpense())
            categoryChartView.alpha = 0.0
        }else {
            categoryChartView.alpha = 1.0
            createPieChart(self.chartVM.gainCategoryNamesWithPie(), values: self.chartVM.gainCategoryRatioWithPie(), money: self.chartVM.gainTotalExpense())
        }
        
        // 更新时间
        self.categoryCurrentTime.text = "\(date.year)年\(date.month)月"
        // 创建完图标后刷新数据
        categoryTableView.reloadData()
    }
    
    // 创建一个环形图
    func createPieChart(dataPoints: [String], values: [Double], money: Double) {
        let dataEntries: [ChartDataEntry] = self.chartVM.createDataEntries(dataPoints.count, values: values)

        let pieChartDataSet = PieChartDataSet(yVals: dataEntries, label: "消费类别图")
        // 设置颜色
        pieChartDataSet.colors = self.chartVM.setColorWithPie()
        pieChartDataSet.sliceSpace = 2.0;
        
        let pieChartData = PieChartData(xVals: dataPoints, dataSet: pieChartDataSet)
        
        // 设置百分比格式
        let pFormatter = NSNumberFormatter()
        pFormatter.numberStyle = .PercentStyle
        pFormatter.maximumFractionDigits = 1;
        pFormatter.multiplier = 1.0;
        pFormatter.percentSymbol = " %";
        pieChartData.setValueFormatter(pFormatter)
        
        categoryChartView.data = pieChartData
        
        categoryChartView.descriptionText         = ""
        categoryChartView.usePercentValuesEnabled = true     // 使数乘100
        categoryChartView.rotationAngle           = 0.0
        categoryChartView.rotationEnabled         = true
        categoryChartView.drawHoleEnabled         = true
        
        categoryChartView.animate(xAxisDuration: 2.0, easingOption: .EaseInOutBack)
        
        // 设置中心文字
        self.setCategoryChartCenterText("总消费\n￥\(money.convertToStrWithTwoFractionDigits())")
    }
    
    /**
     设置图表中心的文字
     
     - parameter text: 需要被设置的文字内容
     */
    func setCategoryChartCenterText(text: String) {
        categoryChartView.centerAttributedText = self.chartVM.setPieChartCenterText(text);
    }
    
    // MARK: - 创建 柱状图    
    func prepareSevenDaysBarChart() {
        if self.chartVM.consumeExpensesInSevenDays.maxElement() == 0.0 {
            sevenDaysChartView.data = nil
            sevenDaysChartView.noDataTextDescription = "您近七天来尚未记录消费"
        }else {
            createSevenDaysBarChart(self.chartVM.sevenDays, values: self.chartVM.consumeExpensesInSevenDays)
        }
    }
    
    // 创建七天消费柱状图
    private func createSevenDaysBarChart(dataPoints: [String], values: [Double]) {
        var dataEntries: [BarChartDataEntry] = []
        
        for i in 0..<dataPoints.count {
            let dataEntry = BarChartDataEntry(value: values[i], xIndex: i)
            dataEntries.append(dataEntry)
        }
        let barChartDataSet = self.chartVM.createBarChartDataSet("七天消费柱状图", dataEntries: dataEntries)
        sevenDaysChartView.data = BarChartData(xVals: dataPoints, dataSets: [barChartDataSet])

        sevenDaysChartView.descriptionText               = ""
        sevenDaysChartView.xAxis.labelPosition           = .Bottom
        sevenDaysChartView.xAxis.drawGridLinesEnabled    = false       // 除去图中的竖线
        sevenDaysChartView.leftAxis.drawGridLinesEnabled = false       // 除去图中的横线
        sevenDaysChartView.rightAxis.enabled             = false       // 隐藏右侧的坐标轴
        sevenDaysChartView.leftAxis.axisMinValue         = 0.0;        // 使柱状的和x坐标轴紧贴
        sevenDaysChartView.setScaleEnabled(false)
        
        // WARNING: - 待测试
        sevenDaysChartView.xAxis.spaceBetweenLabels      = 1
    }
    
    // MARK: - 创建走势图
    // 创建一年的每月消费走势图
    
    func prepareThirdWeeksTrendChart() {
        
        // 如果当年每月的消费记录中最大值为0， 说明当年未记录消费，则隐藏数据
        if self.chartVM.consumeExpensesInLastThirdWeeks.count == 0 {
            thirdWeeksChartView.data = nil
            sevenDaysChartView.noDataTextDescription = "您近三周来尚未记录消费"
        }else {
            createThirdWeeksTrendChart(self.chartVM.weekdays, values: self.chartVM.consumeExpensesInLastThirdWeeks)
        }
    }
    
    private func createThirdWeeksTrendChart(dataPoints: [String], values: [[Double]]) {
        // 配置图表数据
        var dataEntries: [[ChartDataEntry]] = []
        for i in 0..<3 {
            dataEntries.append(self.chartVM.createDataEntries(dataPoints.count, values: values[i]))
        }
        
        let lineChartDataSets = self.chartVM.createLineChartDataSets(dataEntries)
        
        // 配置图表
        thirdWeeksChartView.noDataTextDescription = "本年度尚未记录消费情况"
        thirdWeeksChartView.descriptionText = ""
        thirdWeeksChartView.xAxis.drawGridLinesEnabled = false     // 除去图中的竖线
        thirdWeeksChartView.rightAxis.enabled = false              // 隐藏右侧的坐标轴
        thirdWeeksChartView.leftAxis.axisMinValue = 0.0;           // 使x坐标轴紧贴
        thirdWeeksChartView.xAxis.labelPosition = .Bottom
        thirdWeeksChartView.setScaleEnabled(false)
        
        thirdWeeksChartView.data = LineChartData(xVals: dataPoints, dataSets: lineChartDataSets)
    }
}

// MARK: - UIScrollView 操作协议
extension ChartViewController: UIScrollViewDelegate {
   
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        //通过scrollView内容的偏移计算当前显示的是第几页
        let page = Int(scrollView.contentOffset.x / scrollView.frame.size.width)
        //设置pageController的当前页
        pageControl.currentPage = page
    }
    
    
    
    // 设置一定会滚动到指定另一个位置
    func scrollViewWillEndDragging(scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let targetOffset: CGPoint = self.nearestTargetOffsetForOffset(targetContentOffset.memory)
        targetContentOffset.memory.x = targetOffset.x
        targetContentOffset.memory.y = targetOffset.y
    }
    
    func nearestTargetOffsetForOffset(offset: CGPoint) -> CGPoint {
        let page: NSInteger = Int(roundf(Float(offset.x / screenWidth)))
        let targetx = screenWidth * CGFloat(page)
        return CGPointMake(targetx, offset.y)
    }
}


// MARK: - TableView 数据源协议
extension ChartViewController: UITableViewDataSource {
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.chartVM.gainNumberOfSection()
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell: FinanceOfCategoryTableViewCell = tableView.dequeueReusableCellWithIdentifier("FinanceCategory") as! FinanceOfCategoryTableViewCell
        
        cell.prepareCollectionCellForChartView(self.chartVM.gainFinanceCategoryAt(indexPath.row))
        
        return cell;
    }
}

// MARK: - TableView 操作协议
extension ChartViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}


// MARK: - （Chart）图形中选择每个元素后的 Delegate
extension ChartViewController: ChartViewDelegate {
    
    // 当 有元素被选中了
    func chartValueSelected(chartView: ChartViewBase, entry: ChartDataEntry, dataSetIndex: Int, highlight: ChartHighlight) {
        if chartView == categoryChartView {
            // 设置中心元素
            let categoryConsume = self.chartVM.gainFinanceCategoryAt(entry.xIndex)
            self.setCategoryChartCenterText("\(categoryConsume.categoryName)\n￥\(categoryConsume.categoryMoney.convertToStrWithTwoFractionDigits())")
        }else if chartView == thirdWeeksChartView {
//            print("thirdWeeksChartView: \(entry) + \(dataSetIndex) + \(highlight)")
        }else if chartView == sevenDaysChartView {
//            print("sevenDaysChartView: \(entry) + \(dataSetIndex) + \(highlight)")
        }
    }
    
    
    func chartValueNothingSelected(chartView: ChartViewBase) {
        if chartView == categoryChartView {
            self.setCategoryChartCenterText("总消费\n￥\(self.chartVM.gainTotalExpense().convertToStrWithTwoFractionDigits())")
        }
    }
}






// MARK: - DZNEmptyDataSetSource 数据源协议
extension ChartViewController: DZNEmptyDataSetSource {
    // 设置图片
    func imageForEmptyDataSet(scrollView: UIScrollView!) -> UIImage! {
        return UIImage(named: "saveMoney")
    }
    
    // 设置文字
    func titleForEmptyDataSet(scrollView: UIScrollView!) -> NSAttributedString! {
        let attribute = [NSFontAttributeName: UIFont.systemFontOfSize(18.0),
                         NSForegroundColorAttributeName: UIColor.grayColor()]
        return NSAttributedString(string: "本月尚未记账", attributes: attribute)
    }
    
    func imageAnimationForEmptyDataSet(scrollView: UIScrollView!) -> CAAnimation! {
        let animation: CABasicAnimation = CABasicAnimation(keyPath: "transform")
        
        animation.fromValue = NSValue.init(CATransform3D: CATransform3DIdentity)
        animation.toValue = NSValue.init(CATransform3D: CATransform3DMakeRotation(CGFloat(M_PI_2), 0.0, 0.0, 1.0))
        
        animation.duration = 0.25
        animation.cumulative = true
        
        return animation
    }
    
}

// MARK: - DZNEmptyDataSetDelegate 操作协议
extension ChartViewController: DZNEmptyDataSetDelegate {
    func emptyDataSetShouldAnimateImageView(scrollView: UIScrollView!) -> Bool {
        return true
    }
}





