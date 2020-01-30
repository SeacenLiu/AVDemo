#  AudioPlayer
播放器实现功能：利用FFmpeg进行解码操作，解码出来的是SInt16格式表示的数据，然后再通过一个ConvertNode将其转换为Float32格式表示的数据，最终输送给RemoteIO Unit进行播放。

![flow chart](./img/flowChart.png)
