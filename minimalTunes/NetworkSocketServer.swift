//
//  NetworkSocketServer.swift
//  minimalTunes
//
//  Created by John Moody on 8/24/16.
//  Copyright © 2016 John Moody. All rights reserved.
//

import Foundation
import CoreData

class MediaServer: NSObject, NSStreamDelegate {
    
    var addr = "127.0.0.1"
    var port = 20012
    var inp: NSInputStream?
    var out: NSOutputStream?
    
    var buffer: [UInt8]? = [0, 0, 0, 0, 0, 0, 0, 0]
    
    var data: NSMutableData?
    
    func connect(host: String, port: Int) {
        
        self.addr = host
        self.port = port
        
        NSStream.getStreamsToHostWithName(host, port: port, inputStream: &inp, outputStream: &out)
        
        if inp != nil && out != nil {
            
            // Set delegate
            inp!.delegate = self
            out!.delegate = self
            
            // Schedule
            inp!.scheduleInRunLoop(.mainRunLoop(), forMode: NSDefaultRunLoopMode)
            out!.scheduleInRunLoop(.mainRunLoop(), forMode: NSDefaultRunLoopMode)
            
            print("Start open()")
            
            // Open!
            inp!.open()
            out!.open()
            print("done opening")
        }
    }
    
    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        print(eventCode)
        if aStream === inp {
            switch eventCode {
            case NSStreamEvent.ErrorOccurred:
                print("input: ErrorOccurred: \(aStream.streamError?.description)")
            case NSStreamEvent.OpenCompleted:
                
                print("input: OpenCompleted")
                
            case NSStreamEvent.EndEncountered:
                decideResponse()
                data = nil
                buffer = nil
            case NSStreamEvent.HasBytesAvailable:
                print("input: HasBytesAvailable")
                inp?.read(&buffer!, maxLength: 8)
                data?.appendBytes(buffer!, length: 8)
                print(data)
            default:
                print(eventCode)
                break
            }
        }
    }
    
    func decideResponse() {
    }

    
    func getSourceList() -> NSData? {
        let fetchRequest = NSFetchRequest(entityName: "SourceListItem")
        let predicate = NSPredicate(format: "playlist != nil")
        fetchRequest.predicate = predicate
        var results: [SourceListItem]?
        do {
            results = try managedContext.executeFetchRequest(fetchRequest) as? [SourceListItem]
        }catch {
            print("error: \(error)")
        }
        guard results != nil else {return nil}
        var serializedResults = [NSMutableDictionary]()
        for item in results! {
            serializedResults.append(item.dictRepresentation())
        }
        var finalObject: NSData?
        do {
            finalObject = try NSJSONSerialization.dataWithJSONObject(serializedResults, options: NSJSONWritingOptions.PrettyPrinted)
        } catch {
            print("error: \(error)")
        }
        return finalObject
    }
    
    func getPlaylist(id: Int) -> NSData? {
        let playlistRequest = NSFetchRequest(entityName: "SongCollection")
        let playlistPredicate = NSPredicate(format: "id == \(id)")
        playlistRequest.predicate = playlistPredicate
        let result: SongCollection? = {
            do {
                let thing = try managedContext.executeFetchRequest(playlistRequest) as! [SongCollection]
                if thing.count > 0 {
                    return thing[0]
                } else {
                    return nil
                }
            } catch {
                print("error: \(error)")
            }
            return nil
        }()
        print(result)
        guard result != nil else {return nil}
        let playlistSongsRequest = NSFetchRequest(entityName: "Track")
        let id_array = result?.track_id_list
        let playlistSongsPredicate = NSPredicate(format: "id in %@", id_array!)
        playlistSongsRequest.predicate = playlistSongsPredicate
        let results: [Track]? = {
            do {
            let thing = try managedContext.executeFetchRequest(playlistSongsRequest) as! [Track]
            if thing.count > 0 {
                return thing
            } else {
                return nil
            }
            } catch {
                print("error: \(error)")
            }
            return nil
        }()
        print(results)
        guard results != nil else {return nil}
        var serializedTracks = [NSMutableDictionary]()
        for track in results! {
            serializedTracks.append(track.dictRepresentation())
        }
        var finalObject: NSData?
        do {
            finalObject = try NSJSONSerialization.dataWithJSONObject(serializedTracks, options: NSJSONWritingOptions.PrettyPrinted)
        } catch {
            print("error: \(error)")
        }
        return finalObject
    }

}

class SocketServer {

}