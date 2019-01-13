# Realtime plane-wave software beamforming with an iPhone

This repo contains the iOS client code used in the paper [Realtime plane-wave software beamforming with an iPhone](https://ieeexplore.ieee.org/document/7728408) presented at IEEE IUS 2016 in Tours, France.

At the time of Tours IUS we had a hard aperture and only handled a single plane-wave. The current state of the code supports dynamic aperture, and multiple, compounded plane-waves. 

## Tours IUS Demo Video

The first version of the client relied on JSON and POST to transmit the data. You can see a slight stutter in this video which is a result of the large (JSON) data frame size. In 2.0.0 we switched to Protobuf and a WebSocket which dramatically increased performance.

[![SmartWave Demo](http://img.youtube.com/vi/L3OwYHYzsYs/0.jpg)](http://www.youtube.com/watch?v=L3OwYHYzsYs "SmartWave Demo")

## Authors

  * [Cameron Lowell Palmer](https://orcid.org/0000-0002-3882-4932)
  * [Ole Marius Hoel Rindal](https://orcid.org/0000-0003-1214-3415)

