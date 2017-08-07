//
//  ResultsViewController.swift
//  VideoIQ
//
//  Created by Sergelenbaatar Tsogtbaatar on 8/6/17.
//  Copyright © 2017 Sergstaeb. All rights reserved.
//

import UIKit
import AVKit

class ResultsViewController: UITableViewController {
    
    var movieURL: URL!
    var predictions: [(time: CMTime, prediction: String)]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UITableViewCell.self,
                           forCellReuseIdentifier: "Cell")
    }
    
    
    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        return predictions.count
    }
    override func tableView(_ tableView: UITableView, cellForRowAt
        indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier:
            "Cell", for: indexPath)
        let prediction = predictions[indexPath.row]
        cell.textLabel?.text = prediction.prediction
        return cell
    }
    
    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        // create a new player from our movie
        let player = AVPlayer(url: movieURL)
        // wrap it inside a view controller
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        // seek to wherever our identified object is
        let prediction = predictions[indexPath.row]
        player.seek(to: prediction.time)
        // show the video now
        present(playerViewController, animated: true)
    }
    
}
