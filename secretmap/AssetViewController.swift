//
//  WebViewController.swift
//  secretmap
//
//  Created by Anton McConville on 2018-03-08.
//  Copyright © 2018 Anton McConville. All rights reserved.
//

import Foundation
import UIKit

class AssetViewController:UIViewController{
    
    @IBOutlet weak var webView:UIWebView!
    
    @IBAction func back(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    var link:String = ""
    
    override func viewDidLoad(){
        super.viewDidLoad()
        
        let url = URL(string: self.link)
        if let unwrappedURL = url{
            let request = URLRequest(url: unwrappedURL)
            let session = URLSession.shared
            
            let task = session.dataTask(with: request){ (data, response, error) in
                
                if error == nil{
                    self.webView.loadRequest(request)
                }else{
                    print(error)
                }
            }
            
            task.resume()
        }
    }
}

