clearGlobalNets
globalNetConnect VDD -type pgpin -pin VDD -instanceBasename *
globalNetConnect VDD -type net -net VDD
globalNetConnect VDD -type tiehi -pin VDD -instanceBasename *
globalNetConnect GND -type pgpin -pin GND -instanceBasename *
globalNetConnect GND -type net -net GND
globalNetConnect GND -type tielo -pin GND -instanceBasename *
globalNetConnect GND -type pgpin -pin VSS -instanceBasename *