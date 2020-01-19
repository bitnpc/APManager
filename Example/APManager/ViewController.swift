//
//  ViewController.swift
//  APManager
//
//  Created by Tony on 12/12/2019.
//  Copyright (c) 2019 Tony. All rights reserved.
//

import UIKit
import APManager

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let tableView: UITableView = UITableView(frame: .zero, style: .plain)
    
    override func viewDidLayoutSubviews() {
        self.tableView.frame = self.view.bounds;
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
//        memoryMonitor.start()
//        anrMonitor.start()
        self.tableView.delegate = self
        self.tableView.dataSource = self;
        self.tableView.register(UITableViewCell.classForCoder(), forCellReuseIdentifier: "cell")
        self.view.addSubview(self.tableView)
        
        // Mock 卡顿
//        self.mockANR()
//         Mock 网络请求
    }
    
    private var timer: DispatchSourceTimer?
    // 每隔 10 秒，休眠 5.5 秒
    func mockANR() -> Void {
        self.timer = DispatchSource.makeTimerSource(queue: .main)
        timer?.schedule(wallDeadline: .now(), repeating: .seconds(10))
        timer?.setEventHandler {
            debugPrint("Enter sleep")
            Thread.sleep(forTimeInterval: 5.5)
        }
        timer?.resume()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 100
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
    
    let fpsMonitor: FPSMonitor = FPSMonitor()
    let anrMonitor: ANRMonitor = ANRMonitor.sharedInstance
    let memoryMonitor: MemoryMonitor = MemoryMonitor.sharedInstance
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        fpsMonitor.start()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        fpsMonitor.stop()
    }
    
}

