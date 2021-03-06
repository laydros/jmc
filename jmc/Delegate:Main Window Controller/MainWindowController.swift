//
//  MainWindowController.swift
//  minimalTunes
//
//  Created by John Moody on 5/30/16.
//  Copyright © 2016 John Moody. All rights reserved.
//

import Cocoa
import CoreData
import AVKit


import MultipeerConnectivity
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

class MainWindowController: NSWindowController, NSSearchFieldDelegate, NSWindowDelegate {
    
    //target views
    var my_context = 0
    //@IBOutlet weak var libraryTableTargetView: NSView!
    @IBOutlet weak var trackQueueTargetView: NSView!
    @IBOutlet weak var librarySplitView: NSSplitView!
    @IBOutlet var noMusicView: NSView!
    @IBOutlet weak var artworkTargetView: NSView!
    @IBOutlet weak var sourceListTargetView: NSView!
    
    //interface elements
    @IBOutlet weak var airplayButton: NSButton!
    @IBOutlet weak var advancedSearchToggle: NSButton!
    @IBOutlet weak var playButton: NSButton!
    @IBOutlet weak var repeatButton: NSButton!
    @IBOutlet weak var parentSplitView: NSSplitView!
    @IBOutlet weak var sourceAreaSplitView: NSSplitView!
    @IBOutlet weak var bitRateFormatter: BitRateFormatter!
    @IBOutlet weak var queueButton: NSButton!
    @IBOutlet weak var volumeSlider: NSSlider!
    @IBOutlet weak var progressBarView: ProgressBarView!
    @IBOutlet weak var shuffleButton: NSButton!
    @IBOutlet weak var trackListTriangle: NSButton!
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var songNameLabel: NSTextField!
    @IBOutlet weak var artistAlbumLabel: NSTextField!
    @IBOutlet weak var durationLabel: NSTextField!
    @IBOutlet weak var currentTimeLabel: NSTextField!
    @IBOutlet weak var theBox: NSBox!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet var artCollectionArrayController: NSArrayController!
    @IBOutlet weak var infoField: NSTextField!
    @IBOutlet weak var barViewToggle: NSView!
    
    //subview controllers
    var sourceListViewController: SourceListViewController!
    var trackQueueViewController: TrackQueueViewController!
    var otherLocalTableViewControllers = NSMutableDictionary()
    var otherSharedTableViewControllers = NSMutableDictionary()
    var currentTableViewController: LibraryTableViewController!
    var albumArtViewController: AlbumArtViewController!
    var advancedFilterViewController: AdvancedFilterViewController?
    
    //subordinate window controllers
    var tagWindowController: TagEditorWindow?
    var equalizerWindowController: EqualizerWindowController?
    var importWindowController: ImportWindowController?
    var testView: ArtistViewController?
    
    //other variables
    var saved_search_bar_content: String?
    var networkedLibraries = NSMutableDictionary()
    var currentAudioSource: SourceListItem?
    var currentSourceListItem: SourceListItem?
    var networkSongWasPlayed = false
    var delegate: AppDelegate!
    var timer: Timer?
    var lastTimerDate: Date?
    var secsPlayed: TimeInterval = 0
    var cur_view_title = "Music"
    var cur_source_title = "Music"
    var duration: Double?
    @objc dynamic var paused: Bool = true
    var is_initialized = false
    @objc dynamic var shuffle: Bool = UserDefaults.standard.bool(forKey: DEFAULTS_SHUFFLE_STRING)
    @objc var will_repeat: Bool = UserDefaults.standard.bool(forKey: DEFAULTS_REPEAT_STRING)
    @objc var showsArtwork: Bool = UserDefaults.standard.bool(forKey: DEFAULTS_SHOWS_ARTWORK_STRING)
    var currentTrack: Track?
    var currentTrackView: TrackView?
    var currentNetworkTrack: Track?
    var currentNetworkTrackView: TrackView?
    //var current_source_play_order: PlaylistOrderObject?
    var current_source_temp_shuffle: PlaylistOrderObject?
    //var current_source_unshuffled_play_order: PlaylistOrderObject?
    //var current_source_index: Int?
    var currentPlaylistOrderObject: PlaylistOrderObject?
    var current_source_index_temp: Int?
    @objc var infoString: String?
    var auxArrayController: NSArrayController?
    var focusedColumn: NSTableColumn?
    var currentOrder: CachedOrder?
    var asc: Bool?
    var is_streaming = false
    var currentLibrary: Library?
    let numberFormatter = NumberFormatter()
    let dateFormatter = DateComponentsFormatter()
    let sizeFormatter = ByteCountFormatter()
    let fileManager = FileManager.default
    var currentFilterPredicate: NSPredicate?
    var isDoneWithSkipOperation = true
    var isDoneWithSkipBackOperation = true
    var durationShowsTimeRemaining = false
    var viewHasLoaded = false
    var subContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    
    //initialize managed object context
    
    //sort descriptors for source list
    var sourceListSortDescriptors: [NSSortDescriptor] = [NSSortDescriptor(key: "sort_order", ascending: true), NSSortDescriptor(key: "name", ascending: true)]
    
    var librarySortDescriptors: [NSSortDescriptor] = [NSSortDescriptor(key: "artist_sort_order", ascending: true)]
    
    @IBAction func importButtonPressed(_ sender: AnyObject) {
        importWindowController = ImportWindowController(windowNibName: NSNib.Name(rawValue: "ImportWindowController"))
        importWindowController?.mainWindowController = self
        importWindowController?.showWindow(self)
    }
    

    @IBAction func searchFieldAction(_ sender: AnyObject) {
        print("search field action called")
        let searchFieldContent = searchField.stringValue
        let searchTokens = searchFieldContent.components(separatedBy: " ").filter({return $0 != ""})
        var subPredicates = [NSPredicate]()
        for token in searchTokens {
            //not accepted by NSPredicateEditor
            //let newPredicate = NSPredicate(format: "ANY {track.name, track.artist.name, track.album.name, track.composer.name, track.comments, track.genre.name} contains[cd] %@", token)
            //accepted by NSPredicateEditor
            let newPredicate = NSPredicate(format: "track.name contains[cd] %@ OR track.artist.name contains[cd] %@ OR track.album.name contains[cd] %@ OR track.composer.name contains[cd] %@ OR track.comments contains[cd] %@ OR track.genre contains[cd] %@", token, token, token, token, token, token)
            subPredicates.append(newPredicate)
        }
        if subPredicates.count > 0 {
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subPredicates)
            currentTableViewController?.trackViewArrayController.filterPredicate = predicate
            currentTableViewController?.searchString = searchFieldContent
        } else {
            currentTableViewController?.trackViewArrayController.filterPredicate = nil
            currentTableViewController?.searchString = nil
        }
    }
    
    func networkPlaylistCallback(_ id: Int, idList: [Int]) {
        print("made it to network playlist callback")
        guard self.otherSharedTableViewControllers.object(forKey: id) != nil else {return}
        let playlistViewController = otherSharedTableViewControllers.object(forKey: id) as! LibraryTableViewControllerCellBased
        playlistViewController.trackViewArrayController.fetchPredicate = NSPredicate(format: "track.id in %@ AND track.is_network == %@", idList, NSNumber(booleanLiteral: true))
        playlistViewController.initializeForPlaylist()
        playlistViewController.tableView.reloadData()
    }
    
    func createPlaylistViewController(_ item: SourceListItem) -> LibraryTableViewController {
        let newPlaylistViewController = LibraryTableViewControllerCellBased(nibName: NSNib.Name(rawValue: "LibraryTableViewControllerCellBased"), bundle: nil)
        newPlaylistViewController.mainWindowController = self
        newPlaylistViewController.managedContext = self.subContext
        newPlaylistViewController.playlist = item.playlist
        newPlaylistViewController.item = item
        return newPlaylistViewController
    }
    
    func addObserversAndInitializeNewTableView(_ table: LibraryTableViewController, item: SourceListItem) {
        table.item = item
        table.mainWindowController = self
        table.managedContext = self.subContext
    }
    
    func switchToPlaylist(_ item: SourceListItem) {
        if item == currentSourceListItem {return}
        currentTableViewController?.hasInitialized = false
        trackQueueViewController?.currentSourceListItem = item
        currentSourceListItem = item
        let objectID = item.objectID
        currentTableViewController?.view.removeFromSuperview()
        if otherLocalTableViewControllers.object(forKey: objectID) != nil && item.is_network != true {
            let playlistViewController = otherLocalTableViewControllers.object(forKey: objectID) as! LibraryTableViewController
            librarySplitView.addArrangedSubview(playlistViewController.view)
            currentTableViewController = playlistViewController
            updateInfo()
        }
        else if otherSharedTableViewControllers.object(forKey: objectID) != nil && item.is_network == true {
            let playlistViewController = otherSharedTableViewControllers.object(forKey: objectID) as! LibraryTableViewController
            librarySplitView.addArrangedSubview(playlistViewController.view)
            currentTableViewController = playlistViewController
            currentTableViewController?.initializeForPlaylist()
            updateInfo()
        }
        else {
            let newPlaylistViewController = createPlaylistViewController(item)
            if item.is_network == true {
                self.otherSharedTableViewControllers[objectID] = newPlaylistViewController
            } else {
                self.otherLocalTableViewControllers[objectID] = newPlaylistViewController
            }
            librarySplitView.addArrangedSubview(newPlaylistViewController.view)
            addObserversAndInitializeNewTableView(newPlaylistViewController, item: item)
            currentTableViewController = newPlaylistViewController
        }
        if currentTableViewController?.advancedFilterVisible == true {
            showAdvancedFilter()
        } else {
            hideAdvancedFilter()
        }
        populateSearchBar()
        currentTableViewController?.tableView.reloadData()
        /*print("doing thing")
        let testView = ArtistViewController(nibName: "ArtistViewController", bundle: nil)
        librarySplitView.addArrangedSubview(testView!.view)
        self.testView = testView*/
    }
    
    func populateSearchBar() {
        if currentTableViewController?.searchString != nil {
            searchField.stringValue = currentTableViewController!.searchString!
        } else {
            searchField.stringValue = ""
        }
    }
    
    func jumpToCurrentSong() {
        currentTableViewController?.jumpToCurrentSong(currentTrack)
    }
    
    func jumpToSelection() {
        currentTableViewController?.jumpToSelection()
    }
    
    @IBAction func volumeDidChange(_ sender: AnyObject) {
        print("volume did change called")
        let newVolume = (sender as! NSSlider).floatValue
        delegate?.audioModule.changeVolume(newVolume)
    }
    //track queue, source logic
    @IBAction func toggleExpandQueue(_ sender: AnyObject) {
        trackQueueViewController!.toggleHidden(queueButton.state.rawValue)
        switch queueButton.state {
        case NSControl.StateValue.on:
            trackQueueTargetView.isHidden = false
            UserDefaults.standard.set(false, forKey: "queueHidden")
        default:
            trackQueueTargetView.isHidden = true
            UserDefaults.standard.set(true, forKey: "queueHidden")
        }
    }
    
    @IBAction func toggleEqualizer(_ sender: Any) {
        print("show equalizer called")
        if self.delegate.equalizerWindowController == nil {
            self.delegate.equalizerWindowController = EqualizerWindowController(windowNibName: NSNib.Name(rawValue: "EqualizerWindowController"))
            self.delegate.equalizerWindowController?.audioModule = self.delegate.audioModule
        }
        if self.delegate.equalizerWindowController?.window?.isVisible == nil || self.delegate.equalizerWindowController?.window?.isVisible == false {
            self.delegate.equalizerWindowController?.showWindow(self)
        }
        self.delegate.equalizerWindowController?.window?.makeKeyAndOrderFront(nil)
    }
    
    func launchGetInfo(_ tracks: [Track]) {
        self.tagWindowController = TagEditorWindow(windowNibName: NSNib.Name(rawValue: "TagEditorWindow"))
        self.tagWindowController?.mainWindowController = self
        self.tagWindowController?.selectedTracks = tracks
        self.window?.addChildWindow(self.tagWindowController!.window!, ordered: .above)
    }
    
    func newSourceAdded() {
        if self.currentSourceListItem == globalRootLibrarySourceListItem {
            self.currentTableViewController?.hasCreatedPlayOrder = false
            self.currentTableViewController?.initializeForLibrary()
        }
    }
    
    func createPlayOrderForTrackID(_ id: Int, row: Int?) -> Int {
        return currentTableViewController!.getUpcomingIDsForPlayEvent(self.shuffleButton.state.rawValue, id: id, row: row)
    }
    
    func getNextTrack() -> Track? {
        let track: Track?
        //todo fix so this isn't a reference to repeatButton
        if self.will_repeat == true {
            return currentTrack
        } else {
            track = trackQueueViewController?.getNextTrack()//this function might change the interface around
            if trackQueueViewController?.currentAudioSource?.is_network == true {
            delegate?.serviceBrowser?.askPeerForSong(trackQueueViewController!.currentAudioSource!.library!.peer as! MCPeerID, id: Int(track!.id!))
                DispatchQueue.main.async {
                    self.initializeInterfaceForNetworkTrack()
                    self.timer?.invalidate()
                }
                delegate?.audioModule.networkFlag = true
            }
            if track == nil && self.currentTrack != nil {
                currentTableViewController?.reloadNowPlayingForTrack(self.currentTrack!)
            }
            return track
        }
    }
    
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        return mainQueueChildContext.undoManager
    }
    
    @IBAction func repeatButtonPressed(_ sender: AnyObject) {
        if repeatButton.state == NSControl.StateValue.on {
            self.will_repeat = true
            UserDefaults.standard.set(true, forKey: DEFAULTS_REPEAT_STRING)
        } else {
            self.will_repeat = true
            UserDefaults.standard.set(false, forKey: DEFAULTS_REPEAT_STRING)
        }
        delegate?.menuDelegate.repeatMenuItem.state = repeatButton.state
    }
    
    @IBAction func shuffleButtonPressed(_ sender: AnyObject) {
        trackQueueViewController?.shufflePressed(shuffleButton.state.rawValue)
        delegate?.menuDelegate.shuffleMenuItem.state = shuffleButton.state
    }
    
    @IBAction func skipBackward(_ sender: Any) {
        self.skipBackward()
    }
    @IBAction func tempBreak(_ sender: AnyObject) {
        self.skip()
        /*print("dongels")
        let fr = NSFetchRequest<Track>(entityName: "Track")
        let result = try? privateQueueParentContext.fetch(fr)
        print(result?.count)*/
    }
    @IBAction func addPlaylistButton(_ sender: AnyObject) {
        sourceListViewController!.createPlaylist(nil, smart_criteria: nil)
    }
    @IBAction func addPlaylistFolderButton(_ sender: AnyObject) {
        sourceListViewController!.createPlaylistFolder(nil)
    }
    @IBAction func addSmartPlaylistButton(_ sender: AnyObject) {
        sourceListViewController!.selectLibrary()
        showAdvancedFilter()
    }
    
    func createPlaylistFromTracks(_ tracks: [Track]) {
        sourceListViewController?.createPlaylist(tracks, smart_criteria: nil)
    }
    func createPlaylistFromSmartCriteria(_ c: SmartCriteria) {
        sourceListViewController?.createPlaylist(nil, smart_criteria: c)
    }
    
    //player stuff
    @IBOutlet weak var artToggle: NSButton!
    
    func initAlbumArtwork(for track: Track) {
        albumArtViewController?.initAlbumArt(track)
    }
    @IBAction func airPlayPressed(_ sender: Any) {
        
    }
    
    @IBAction func toggleArtwork(_ sender: AnyObject) {
        if self.artworkTargetView.isHidden == false {
            artToggle.state = NSControl.StateValue.off
            UserDefaults.standard.set(false, forKey: DEFAULTS_SHOWS_ARTWORK_STRING)
            self.artworkTargetView.isHidden = true
        } else {
            artToggle.state = NSControl.StateValue.on
            UserDefaults.standard.set(true, forKey: DEFAULTS_SHOWS_ARTWORK_STRING)
            self.artworkTargetView.isHidden = false
        }
    }

    func playNetworkSongCallback() {
        guard self.is_streaming == true else {return}
        if trackQueueViewController?.trackQueue.count < 1 || networkSongWasPlayed == true {
            //trackQueueViewController?.changeCurrentTrack(self.currentTrack!)
            if networkSongWasPlayed == true {
                networkSongWasPlayed = false
            }
        }
        delegate?.audioModule.playNetworkImmediately(self.currentTrack!)
        //initializeInterfaceForNewTrack()
        paused = false
    }
    
    func handleTrackMissing(track: Track) {
        track.is_available = false
    }
    
    func playSong(_ track: Track, row: Int?) -> Bool {
        guard fileManager.fileExists(atPath: URL(string: track.location!)!.path) else {
            sourceListViewController!.reloadData()
            handleTrackMissing(track: track)
            currentTableViewController?.reloadDataForTrack(track, orRow: row)
            return false
        }
        if track.is_network == true {
            self.is_streaming = true
            initializeInterfaceForNetworkTrack()
            let peer = sourceListViewController!.getCurrentSelectionSharedLibraryPeer()
            delegate?.audioModule.stopForNetworkTrack()
            delegate?.serviceBrowser?.getTrack(Int(track.id!), peer: peer)
            if self.currentTrack != nil {
                notEnablingUndo {
                    currentTrack?.is_playing = false
                }
                currentTableViewController?.reloadNowPlayingForTrack(self.currentTrack!)
            }
            currentTrack = track
            networkSongWasPlayed = true
            trackQueueViewController?.createPlayOrderArray(track, row: row)
            trackQueueViewController?.changeCurrentTrack(self.currentTrack!)
            return true
        } else {
            self.is_streaming = false
        }
        if (paused == true && delegate?.audioModule.is_initialized == true) {
            unpause()
        }
        trackQueueViewController?.createPlayOrderArray(track, row: row)
        delegate?.audioModule.playImmediately(track.location!)
        trackQueueViewController?.changeCurrentTrack(track)
        paused = false
        //currentTrack = track
        return true
    }
    
    func shuffle_array(_ array: inout [Int]) {
        guard array.count > 0 else {return}
        for i in 0..<array.count - 1 {
            let j = Int(arc4random_uniform(UInt32(array.count - i))) + i
            guard i != j else {continue}
            array.swapAt(i, j)
        }
    }
    
    func playAnything() {
        if trackQueueViewController?.trackQueue.count == 0 {
            let trackToPlay = currentTableViewController!.getTrackWithNoContext(shuffleButton.state.rawValue)
            if trackToPlay != nil {
                playSong(trackToPlay!, row: nil)
            }
        } else {
            delegate?.audioModule.skip()
        }
    }
    
    func interpretDeleteEvent(_ selectedObjects: [TrackView]) {
        let alert = NSAlert()
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.messageText = kDeleteEventText
        let response = alert.runModal()
        if response == NSApplication.ModalResponse.alertFirstButtonReturn {
            print("deleting tracks")
            self.delegate?.databaseManager?.removeTracks(selectedObjects.map({return $0.track!}))
        }
    }
    
    func interpretSpacebarEvent() {
        if currentTrack != nil {
            if paused == true {
                unpause()
            } else if paused == false {
                pause()
            }
        } else {
            playAnything()
        }
    }
    
    func pause() {
        paused = true
        print("pause called")
        updateValuesUnsafe()
        delegate?.audioModule.pause()
        timer!.invalidate()
        playButton.image = NSImage(named: NSImage.Name(rawValue: "NSPlayTemplate"))
    }
    
    func unpause() {
        print("unpause called")
        paused = false
        lastTimerDate = Date()
        delegate?.audioModule.play()
        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(updateValuesSafe), userInfo: nil, repeats: true)
        RunLoop.current.add(timer!, forMode: RunLoopMode.commonModes)
        playButton.image = NSImage(named: NSImage.Name(rawValue: "NSPauseTemplate"))
    }
    
    func seek(_ frac: Double) {
        delegate?.audioModule.seek(frac)
        //callback is seekCompleted()
    }
    
    func seekCompleted() {
        DispatchQueue.main.async {
            self.updateValuesUnsafe()
            self.timer?.invalidate()
            self.timer = nil
            self.startTimer()
        }
    }
    
    func skip() {
        guard trackQueueViewController!.currentTrack != nil else {return}
        guard self.isDoneWithSkipOperation else {print("can't skip");return}
        self.isDoneWithSkipOperation = false
        notEnablingUndo {
            self.currentTrack?.is_playing = false
        }
        timer?.invalidate()
        delegate?.audioModule.skip()
    }
    
    func skipBackward() {
        guard trackQueueViewController!.currentTrack != nil else {return}
        guard self.isDoneWithSkipBackOperation else {print("can't skip backward");return}
        self.isDoneWithSkipBackOperation = false
        notEnablingUndo {
            self.currentTrack?.is_playing = false
        }
        timer?.invalidate()
        let nodeTime = delegate?.audioModule.curPlayerNode.lastRenderTime
        let playerTime = delegate?.audioModule.curPlayerNode.playerTime(forNodeTime: nodeTime!)
        var offset_thing: Double?
        if delegate?.audioModule.track_frame_offset == nil {
            offset_thing = 0
        }
        else {
            offset_thing  = delegate?.audioModule.track_frame_offset!
            print(offset_thing)
        }
        if playerTime != nil {
            let seconds = ((Double((playerTime?.sampleTime)!) + offset_thing!) / (playerTime?.sampleRate)!) - Double(delegate!.audioModule.total_offset_seconds)
            if seconds > 3 {
                delegate?.audioModule.skip_backward()
                initializeInterfaceForNewTrack()
                self.isDoneWithSkipBackOperation = true
            } else {
                trackQueueViewController?.skipToPreviousTrack()
            }
        } else {
            trackQueueViewController?.skipToPreviousTrack()
        }
    }
    
    
    @IBAction func playPressed(_ sender: AnyObject) {
        print("called")
        if (paused == true) {
            //if not initialized, play selected track/shuffle
            if is_initialized == false {
                playAnything()
            }
            unpause()
            paused = false
        }
        else {
            pause()
            paused = true
        }
    }
    @IBAction func advancedFilterButtonPressed(_ sender: AnyObject) {
        if sender is AppDelegate {
            self.advancedSearchToggle.state = self.advancedSearchToggle.state == NSControl.StateValue.on ? NSControl.StateValue.off : NSControl.StateValue.on
        }
        if advancedSearchToggle.state == NSControl.StateValue.on {
            showAdvancedFilter()
        } else {
            hideAdvancedFilter()
        }
    }
    
    func showAdvancedFilter() {
        if advancedFilterViewController?.view == nil {
            self.advancedFilterViewController = AdvancedFilterViewController(tableViewController: self.currentTableViewController!)
            //self.advancedFilterViewController = AdvancedFilterViewController(nibName: "AdvancedFilterViewController", bundle: nil)
            advancedFilterViewController!.mainWindowController = self
            librarySplitView.insertArrangedSubview(advancedFilterViewController!.view, at: 0)
            advancedFilterViewController?.initializePredicateEditor()
            self.advancedSearchToggle.state = NSControl.StateValue.on
        }
    }
    
    func hideAdvancedFilter() {
        if advancedFilterViewController != nil {
            advancedFilterViewController!.view.removeFromSuperview()
            self.advancedFilterViewController = nil
            currentTableViewController?.advancedFilterVisible = false
        }
        self.advancedSearchToggle.state = NSControl.StateValue.off
    }
    
    func initializeInterfaceForNetworkTrack() {
        theBox.contentView?.isHidden = false
        print("initializing interface for network track")
        self.timer?.invalidate()
        self.progressBar.isIndeterminate = true
        self.progressBar.startAnimation(nil)
        self.songNameLabel.stringValue = "Initializing playback..."
        self.artistAlbumLabel.stringValue = ""
        self.durationLabel.stringValue = ""
        self.currentTimeLabel.stringValue = ""
        barViewToggle.isHidden = true
    }
    
    func initializeInterfaceForNewTrack() {
        print("paused value in mwc is \(paused)")
        if self.progressBar.isIndeterminate == true {
            self.progressBar.stopAnimation(nil)
            self.progressBar.isIndeterminate = false
        }
        var aa_string = ""
        var name_string = ""
        let the_track = self.currentTrack!
        if !UserDefaults.standard.bool(forKey: DEFAULTS_ARTWORK_SHOWS_SELECTED) {
            albumArtViewController?.initAlbumArt(the_track)
        }
        name_string = the_track.name!
        if the_track.artist != nil {
            aa_string += (the_track.artist! as Artist).name!
            if the_track.album != nil {
                aa_string += (" - " + (the_track.album! as Album).name!)
            }
        }
        barViewToggle.isHidden = true
        timer?.invalidate()
        theBox.contentView!.isHidden = false
        songNameLabel.stringValue = name_string
        artistAlbumLabel.stringValue = aa_string
        duration = delegate?.audioModule.duration_seconds
        if self.durationShowsTimeRemaining {
            durationLabel.stringValue = "-\(getTimeAsString(duration!)!)"
        } else {
            durationLabel.stringValue = getTimeAsString(duration!)!
        }
        currentTimeLabel.stringValue = getTimeAsString(0)!
        lastTimerDate = Date()
        secsPlayed = 0
        progressBar.isHidden = false
        progressBar.doubleValue = 0
        if paused != true {
            startTimer()
        }
    }

    func startTimer() {
        //timer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: #selector(updateValuesUnsafe), userInfo: nil, repeats: true)
        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(updateValuesSafe), userInfo: nil, repeats: true)
        RunLoop.current.add(timer!, forMode: RunLoopMode.commonModes)
        playButton.image = NSImage(named: NSImage.Name(rawValue: "NSPauseTemplate"))
    }
    
    func updateValuesUnsafe() {
        print("unsafe called")
        if self.delegate?.audioModule.isSeeking != true {
            if let nodeTime = delegate?.audioModule.curPlayerNode.lastRenderTime, let playerTime = delegate?.audioModule.curPlayerNode.playerTime(forNodeTime: nodeTime), let duration = self.duration, duration != 0 {
                let offset: Double = delegate?.audioModule.track_frame_offset ?? 0
                let seconds = (Double(playerTime.sampleTime) + offset) / (playerTime.sampleRate) - delegate.audioModule.total_offset_seconds
                if let seconds_string = getTimeAsString(seconds) {
                    currentTimeLabel.stringValue = seconds_string
                    print(seconds_string)
                }
                progressBar.doubleValue = (seconds * 100) / duration
                if self.durationShowsTimeRemaining {
                    durationLabel.stringValue = "-\(getTimeAsString(duration - secsPlayed)!)"
                }
                secsPlayed = seconds
                lastTimerDate = Date()
            }
        }
    }
    
    @objc func updateValuesSafe() {
        let lastUpdateTime = lastTimerDate
        let currentTime = Date()
        let updateQuantity = currentTime.timeIntervalSince(lastUpdateTime!)
        secsPlayed += updateQuantity
        let seconds_string = getTimeAsString(secsPlayed)
        if timer?.isValid == true {
            currentTimeLabel.stringValue = seconds_string!
            if self.durationShowsTimeRemaining {
                durationLabel.stringValue = "-\(getTimeAsString(duration! - secsPlayed)!)"
            }
            progressBar.doubleValue = (secsPlayed * 100) / duration!
            progressBar.displayIfNeeded()
            lastTimerDate = currentTime
        } else {
            timer?.invalidate()
            //print("doingle")
            //currentTimeLabel.stringValue = ""
            //progressBar.doubleValue = 0
        }
    }
    
    
    @IBAction func durationLabelOnClick(_ sender: AnyObject) {
        durationShowsTimeRemaining = !durationShowsTimeRemaining
        if durationShowsTimeRemaining == false {
            durationLabel.stringValue = getTimeAsString(self.duration!)!
        }
        UserDefaults.standard.set(durationShowsTimeRemaining, forKey: DEFAULTS_DURATION_SHOWS_TIME_REMAINING)
    }
    
    func cleanUpBar() {
        print("other doingle")
        theBox.contentView!.isHidden = true
        songNameLabel.stringValue = ""
        artistAlbumLabel.stringValue = ""
        duration = 0
        durationLabel.stringValue = ""
        currentTimeLabel.stringValue = ""
        progressBar.doubleValue = 100
    }
    
    func incrementPlayCountForCurrentTrack() {
        self.currentTrack?.play_count = (self.currentTrack?.play_count as? Int ?? 0) + 1 as NSNumber
        self.currentTrack?.date_last_played = NSDate()
        let timeNow = Date()
        let timeInterval = -secsPlayed
        let timeTrackStarted = timeNow.addingTimeInterval(timeInterval)
        delegate?.lastFMDelegate?.scrobble(track: self.currentTrack!, timestamp: timeTrackStarted)
        print("seconds played: \(secsPlayed)")
    }
    
    func checkPlayFractionForSkip() {
        if self.progressBar.doubleValue / 100.0 > UserDefaults.standard.double(forKey: DEFAULTS_TRACK_PLAY_REGISTER_POINT) {
            incrementPlayCountForCurrentTrack()
        }
        incrementSkipCountForCurrentTrack()
    }
    
    func incrementSkipCountForCurrentTrack() {
        self.currentTrack?.skip_count = (self.currentTrack?.skip_count as? Int ?? 0) + 1 as NSNumber
        self.currentTrack?.date_last_skipped = NSDate()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &my_context {
            if keyPath! == "track_changed" {
                print("controller detects track change")
                if trackQueueViewController?.upcomingTrack != nil {
                    trackQueueViewController.addTrackToQueue(trackQueueViewController.upcomingTrack!, context: trackQueueViewController.currentAudioSource!.name!, tense: 2, manually: false)
                    trackQueueViewController.upcomingTrack = nil
                }
                self.progressBarView.blockSeekEvents()
                notEnablingUndo {
                    self.currentTrack?.is_playing = false
                }
                if currentTrack != nil {
                    if delegate?.audioModule.lastTrackCompletionType == .natural {
                        incrementPlayCountForCurrentTrack()
                    } else {
                        checkPlayFractionForSkip()
                    }
                    currentTableViewController?.reloadNowPlayingForTrack(currentTrack!)
                }
                trackQueueViewController!.nextTrack()
                currentTrack = trackQueueViewController?.trackQueue[trackQueueViewController!.currentTrackIndex!].track
                if is_initialized == false {
                    //trackQueueViewController!.createPlayOrderArray(self.currentTrack!, row: nil)
                    paused = false
                    is_initialized = true
                }
                timer?.invalidate()
                initializeInterfaceForNewTrack()
                notEnablingUndo {
                    self.currentTrack?.is_playing = true
                }
                currentTableViewController?.reloadNowPlayingForTrack(currentTrack!)
                self.isDoneWithSkipOperation = true
                self.isDoneWithSkipBackOperation = true
                if UserDefaults.standard.bool(forKey: DEFAULTS_TABLE_SKIP_SHOWS_NEW_TRACK) {
                    currentTableViewController?.scrollToNewTrack()
                }
            }
            else if keyPath! == "done_playing" {
                print("controller detects finished playing")
                cleanUpBar()
                trackQueueViewController?.cleanUp()
            }
            else if keyPath! == "sortDescriptors" {
                self.trackQueueViewController!.modifyPlayOrderForSortDescriptorChange()
            }
            else if keyPath! == "filterPredicate" {
                print("filter predicate changed")
                currentTableViewController?.fixPlayOrderForChangedFilterPredicate(shuffleButton.state.rawValue)
                /*if (trackQueueViewController!.currentSourceListItem == trackQueueViewController!.currentAudioSource) && trackQueueViewController?.currentAudioSource!.playOrderObject != nil {
                    currentTableViewController!.fixPlayOrderForChangedFilterPredicate(trackQueueViewController!.currentAudioSource!.playOrderObject!, shuffleState: shuffleButton.state)
                }*/
            } else if keyPath! == "arrangedObjects" {
                updateInfo()
            } else if keyPath! == "albumArtworkAdded" {
                self.trackQueueViewController?.reloadData()
                print("reloaded data")
            } else if keyPath! == "paused" {
                self.trackQueueViewController?.reloadCurrentTrack()
            }
        }
    }
    
    func updateInfo() {
        print("updateinfo called")
        if self.currentTableViewController == nil {
            return
        }
        privateQueueParentContext.perform {
            let trackArray = (self.currentTableViewController?.trackViewArrayController?.arrangedObjects as! [TrackView]).map({return privateQueueParentContext.object(with: $0.objectID) as! TrackView})
            print("finished casting items")
            let numItems = trackArray.count as NSNumber
            let totalSize = trackArray.lazy.flatMap({return ($0.track?.size?.int64Value)}).reduce(0, {$0 + $1})
            let totalTime = trackArray.lazy.flatMap({return ($0.track?.time?.doubleValue)}).reduce(0, {$0 + $1})
            let numString = self.numberFormatter.string(from: numItems)
            let sizeString = self.sizeFormatter.string(fromByteCount: totalSize)
            let timeString = self.dateFormatter.string(from: totalTime/1000)
            DispatchQueue.main.async {
                self.infoString = "\(numString!) items; \(timeString!); \(sizeString)"
                self.infoField.stringValue = self.self.infoString!
            }
        }
    }
    
    @IBAction func trackListTriangleClicked(_ sender: AnyObject) {
        print("break")
    }
    
    func refreshCurrentSortOrder() {
        if let key = self.currentTableViewController?.tableView.sortDescriptors.first?.key,
            let orderName = keyToCachedOrderDictionary[key],
            let order = cachedOrders![orderName] {
            print("fixing indices for current order")
            fixIndicesImmutable(order: order)
            self.currentTableViewController?.trackViewArrayController.rearrangeObjects()
        }
    }
    
    func cachePlayOrderObject() {
        
    }
    
    //mark album art
    
    func makeDark() {
        self.window?.appearance = NSAppearance(named: NSAppearance.Name.vibrantDark)
        theBox.fillColor = NSColor(patternImage: NSImage(named: NSImage.Name(rawValue: "Inverted Gradient"))!)
        let color = NSColor.white
        let attrs = [NSAttributedStringKey.foregroundColor : color]
        let newAttributedString = NSAttributedString(string: "Search", attributes: attrs)
        (searchField.cell as! NSSearchFieldCell).placeholderAttributedString = newAttributedString
    }
    
    override func windowDidLoad() {
        self.sourceListViewController = SourceListViewController(nibName: NSNib.Name(rawValue: "SourceListViewController"), bundle: nil)
        sourceListTargetView.addSubview(sourceListViewController!.view)
        self.sourceListViewController!.view.frame = sourceListTargetView.bounds
        let sourceListLayoutConstraints = [NSLayoutConstraint(item: sourceListViewController!.view, attribute: .left, relatedBy: .equal, toItem: sourceListTargetView, attribute: .left, multiplier: 1, constant: 0), NSLayoutConstraint(item: sourceListViewController!.view, attribute: .right, relatedBy: .equal, toItem: sourceListTargetView, attribute: .right, multiplier: 1, constant: 0), NSLayoutConstraint(item: sourceListViewController!.view, attribute: .top, relatedBy: .equal, toItem: sourceListTargetView, attribute: .top, multiplier: 1, constant: 0), NSLayoutConstraint(item: sourceListViewController!.view, attribute: .bottom, relatedBy: .equal, toItem: sourceListTargetView, attribute: .bottom, multiplier: 1, constant: 0)]
        NSLayoutConstraint.activate(sourceListLayoutConstraints)
        self.sourceListViewController?.mainWindowController = self
        self.albumArtViewController = AlbumArtViewController(nibName: NSNib.Name(rawValue: "AlbumArtViewController"), bundle: nil)
        artworkTargetView.addSubview(albumArtViewController!.view)
        let artworkLayoutConstraints = [NSLayoutConstraint(item: albumArtViewController!.view, attribute: .left, relatedBy: .equal, toItem: artworkTargetView, attribute: .left, multiplier: 1, constant: 0), NSLayoutConstraint(item: albumArtViewController!.view, attribute: .right, relatedBy: .equal, toItem: artworkTargetView, attribute: .right, multiplier: 1, constant: 0), NSLayoutConstraint(item: albumArtViewController!.view, attribute: .top, relatedBy: .equal, toItem: artworkTargetView, attribute: .top, multiplier: 1, constant: 0), NSLayoutConstraint(item: albumArtViewController!.view, attribute: .bottom, relatedBy: .equal, toItem: artworkTargetView, attribute: .bottom, multiplier: 1, constant: 0)]
        NSLayoutConstraint.activate(artworkLayoutConstraints)
        self.albumArtViewController!.view.frame = artworkTargetView.bounds
        self.trackQueueViewController = TrackQueueViewController(nibName: NSNib.Name(rawValue: "TrackQueueViewController"), bundle: nil)
        trackQueueTargetView.addSubview(trackQueueViewController!.view)
        self.trackQueueViewController!.view.frame = trackQueueTargetView.bounds
        let trackQueueLayoutConstraints = [NSLayoutConstraint(item: trackQueueViewController!.view, attribute: .left, relatedBy: .equal, toItem: trackQueueTargetView, attribute: .left, multiplier: 1, constant: 0), NSLayoutConstraint(item: trackQueueViewController!.view, attribute: .right, relatedBy: .equal, toItem: trackQueueTargetView, attribute: .right, multiplier: 1, constant: 0), NSLayoutConstraint(item: trackQueueViewController!.view, attribute: .top, relatedBy: .equal, toItem: trackQueueTargetView, attribute: .top, multiplier: 1, constant: 0), NSLayoutConstraint(item: trackQueueViewController!.view, attribute: .bottom, relatedBy: .equal, toItem: trackQueueTargetView, attribute: .bottom, multiplier: 1, constant: 0)]
        NSLayoutConstraint.activate(trackQueueLayoutConstraints)
        self.trackQueueViewController?.mainWindowController = self
        //self.libraryTableViewController = LibraryTableViewController(nibName: "LibraryTableViewController", bundle: nil)
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        dateFormatter.unitsStyle = DateComponentsFormatter.UnitsStyle.full
        self.delegate!.audioModule.mainWindowController = self
        progressBar.isDisplayedWhenStopped = true
        progressBarView.progressBar = progressBar
        progressBarView.mainWindowController = self
        //vintage playback view
        theBox.contentView?.isHidden = true
        theBox.boxType = .custom
        theBox.borderType = .bezelBorder
        theBox.borderWidth = 1.1
        theBox.cornerRadius = 3
        theBox.fillColor = NSColor(patternImage: NSImage(named: NSImage.Name(rawValue: "Gradient"))!)
        searchField.delegate = self
        //searchField.drawsBackground = false
        self.delegate?.audioModule.addObserver(self, forKeyPath: "track_changed", options: .new, context: &my_context)
        self.delegate?.audioModule.addObserver(self, forKeyPath: "done_playing", options: .new, context: &my_context)
        self.addObserver(self, forKeyPath: "paused", options: .new, context: &my_context)
        self.albumArtViewController?.addObserver(self, forKeyPath: "albumArtworkAdded", options: .new, context: &my_context)
        self.albumArtViewController?.mainWindow = self
        trackQueueViewController?.mainWindowController = self
        volumeSlider.isContinuous = true
        self.window!.titleVisibility = NSWindow.TitleVisibility.hidden
        self.window!.titlebarAppearsTransparent = true
        UserDefaults.standard.set(true, forKey: "checkEmbeddedArtwork")
        let userScreenSize = NSScreen.main?.frame.width
        /*let songBarMinimumWidthConstraint = NSLayoutConstraint(item: theBox, attribute: .width, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: userScreenSize! * MIN_SONG_BAR_WIDTH_FRACTION)
        let volumeBarMinimumWidthConstraint = NSLayoutConstraint(item: volumeSlider, attribute: .width, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: userScreenSize! * MIN_VOLUME_BAR_WIDTH_FRACTION)
        let searchBarMinimumWidthConstraint = NSLayoutConstraint(item: searchField, attribute: .width, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: userScreenSize! * MIN_SEARCH_BAR_WIDTH_FRACTION)
        let volumeSliderMaxWidthConstraint = NSLayoutConstraint(item: volumeSlider, attribute: .width, relatedBy: .lessThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: userScreenSize! * MAX_VOLUME_BAR_WIDTH_FRACTION)
        NSLayoutConstraint.activate([songBarMinimumWidthConstraint, volumeBarMinimumWidthConstraint, searchBarMinimumWidthConstraint, volumeSliderMaxWidthConstraint])*/
        let volume = UserDefaults.standard.float(forKey: DEFAULTS_VOLUME_STRING)
        volumeSlider.floatValue = volume
        volumeDidChange(volumeSlider)
        super.windowDidLoad()
        sourceListViewController?.selectStuff()
        let clickRecognizer = NSClickGestureRecognizer()
        clickRecognizer.buttonMask = 0x1
        clickRecognizer.numberOfClicksRequired = 1
        clickRecognizer.action = #selector(durationLabelOnClick)
        durationLabel.addGestureRecognizer(clickRecognizer)
        delegate?.menuDelegate.shuffleMenuItem.state = shuffleButton.state
        delegate?.menuDelegate.repeatMenuItem.state = repeatButton.state
        self.window?.isMovableByWindowBackground = true
        UserDefaults.standard.set(false, forKey: jmcDarkAppearanceOption)
        if UserDefaults.standard.bool(forKey: jmcDarkAppearanceOption) {
            makeDark()
        }
        barViewToggle.isHidden = true
        //self.window?.invalidateShadow()
        self.durationShowsTimeRemaining = UserDefaults.standard.bool(forKey: DEFAULTS_DURATION_SHOWS_TIME_REMAINING)
        /*if #available(OSX 10.13, *) {
            self.airplayButton.isHidden = false
        } else {
            self.airplayButton.isHidden = true
            // Fallback on earlier versions
        }*/
    }
    /*@IBAction func airPlayButtonPressed(_ sender: Any) {
        let popover = NSPopover()
        if #available(OSX 10.13, *) {
            (self.delegate.audioModule.routeDetector as! AVRouteDetector).multipleRoutesDetected
        } else {
            // Fallback on earlier versions
        }
        
    }*/
}
