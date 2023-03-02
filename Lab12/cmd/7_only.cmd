setSrouteMode -viaConnectToShape { ring }
sroute -connect { padPin } -layerChangeRange { met1(1) met6(6) } -blockPinTarget { nearestTarget } -padPinPortConnect { allPort oneGeom } -padPinTarget { nearestTarget } -allowJogging 1 -crossoverViaLayerRange { met1(1) met6(6) } -nets { GND VDD } -allowLayerChange 1 -targetViaLayerRange { met1(1) met6(6) }
