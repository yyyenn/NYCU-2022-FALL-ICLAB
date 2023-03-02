setSrouteMode -viaConnectToShape { ring stripe }
sroute -connect { corePin } -layerChangeRange { met1(1) met6(6) } -blockPinTarget { nearestTarget } -corePinTarget { firstAfterRowEnd } -allowJogging 1 -crossoverViaLayerRange { met1(1) met6(6) } -nets { GND VDD } -allowLayerChange 1 -targetViaLayerRange { met1(1) met6(6) }
