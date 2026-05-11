//
//  CommuteWidgetBundle.swift
//  CommuteWidget
//
//  Created by Rommel on 9/5/26.
//

import WidgetKit
import SwiftUI

@main
struct CommuteWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Our real widgets:
        QuickActionsWidget()
        MRTStatusWidget()
        NextOutTheDoorWidget()
        PinnedItemsWidget()
        BusTrackingLiveActivity()
    }
}
