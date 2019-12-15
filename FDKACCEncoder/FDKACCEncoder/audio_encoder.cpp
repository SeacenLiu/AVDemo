#include "audio_encoder.h"

#define LOG_TAG "AudioEncoder"

AudioEncoder::AudioEncoder() {
}

AudioEncoder::~AudioEncoder() {
}

#pragma mark - 生成音频流
int AudioEncoder::alloc_audio_stream(const char * codec_name) {
	AVCodec *codec; // 编码器
	AVSampleFormat preferedSampleFMT = AV_SAMPLE_FMT_S16; // signed 16 bits
	int preferedChannels = audioChannels; // 声道数
	int preferedSampleRate = audioSampleRate; // 音频采样率
    // 创建音频流
	audioStream = avformat_new_stream(avFormatContext, NULL);
	audioStream->id = 1;
    // 创建编码上下文
    avCodecContext = audioStream->codec;
	avCodecContext->codec_type = AVMEDIA_TYPE_AUDIO;
	avCodecContext->sample_rate = audioSampleRate;
	if (publishBitRate > 0) {
		avCodecContext->bit_rate = publishBitRate;
	} else {
		avCodecContext->bit_rate = PUBLISH_BITE_RATE;
	}
	avCodecContext->sample_fmt = preferedSampleFMT;
	LOGI("audioChannels is %d", audioChannels);
    // 声道布局
    // AV_CH_LAYOUT_MONO: 单声道
    // AV_CH_LAYOUT_STEREO: 立体声（2通道，左右左右布局）
    avCodecContext->channel_layout = preferedChannels == 1 ? AV_CH_LAYOUT_MONO : AV_CH_LAYOUT_STEREO;
    // 根据声道布局生成声道数
	avCodecContext->channels = av_get_channel_layout_nb_channels(avCodecContext->channel_layout);
    LOGI("avCodecContext->channels is %d", avCodecContext->channels);
    avCodecContext->profile = FF_PROFILE_AAC_LOW;
	avCodecContext->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    // 根据名字获取编码器
	codec = avcodec_find_encoder_by_name(codec_name);
	if (!codec) {
		LOGI("Couldn't find a valid audio codec");
		return -1;
	}
	avCodecContext->codec_id = codec->id; // 设置编码上下文的编码器ID，指明使用的编码器

	if (codec->sample_fmts) {
		/* check if the prefered sample format for this codec is supported.
		 * this is because, depending on the version of libav, and with the whole ffmpeg/libav fork situation,
		 * you have various implementations around. float samples in particular are not always supported.
		 */
		const enum AVSampleFormat *p = codec->sample_fmts;
		for (; *p != -1; p++) {
            // 可用 audioStream->codecpar->format 替代 audioStream->codec->sample_fmt
            // format 与 sample_fmt 枚举值一一对应
			if (*p == audioStream->codec->sample_fmt)
				break;
		}
		if (*p == -1) {
			LOGI("sample format incompatible with codec. Defaulting to a format known to work.........");
			/* sample format incompatible with codec. Defaulting to a format known to work */
			avCodecContext->sample_fmt = codec->sample_fmts[0];
		}
	}
    
    // 最优采样率设置
	if (codec->supported_samplerates) {
		const int *p = codec->supported_samplerates; // 所有支持的采样率
		int best = 0;
		int best_dist = INT_MAX;
		for (; *p; p++) {
            // 找与音频流最接近的采样率进行设置
			int dist = abs(audioStream->codec->sample_rate - *p);
			if (dist < best_dist) {
				best_dist = dist;
				best = *p;
			}
		}
		/* best is the closest supported sample rate (same as selected if best_dist == 0) */
		avCodecContext->sample_rate = best;
	}
    // 检查外部设置的参数是否和编码器上下文相符合
    // 不一样的话就需要进行重采样，向编码上下文靠拢
	if (preferedChannels != avCodecContext->channels         // 声道数
        || preferedSampleRate != avCodecContext->sample_rate // 采样率
        || preferedSampleFMT != avCodecContext->sample_fmt)  // 样本格式
    {
		LOGI("channels is {%d, %d}", preferedChannels, audioStream->codec->channels);
		LOGI("sample_rate is {%d, %d}", preferedSampleRate, audioStream->codec->sample_rate);
		LOGI("sample_fmt is {%d, %d}", preferedSampleFMT, audioStream->codecpar->format);
		LOGI("AV_SAMPLE_FMT_S16P is %d AV_SAMPLE_FMT_S16 is %d AV_SAMPLE_FMT_FLTP is %d", AV_SAMPLE_FMT_S16P, AV_SAMPLE_FMT_S16, AV_SAMPLE_FMT_FLTP);
		swrContext = swr_alloc_set_opts(NULL, // 已存在的 Swr context
                                        av_get_default_channel_layout(avCodecContext->channels), // 输出声道布局
                                        (AVSampleFormat)avCodecContext->sample_fmt, // 输出样本格式
                                        avCodecContext->sample_rate, // 输出样本采样率
                                        av_get_default_channel_layout(preferedChannels), // 输入声道格式
                                        preferedSampleFMT, // 输入样本格式
                                        preferedSampleRate, // 输入样本采样率
                                        0, // logging level offset
                                        NULL); // parent logging context, can be NULL
		if (!swrContext || swr_init(swrContext)) { // 初始化 swrContext
			if (swrContext)
				swr_free(&swrContext);
			return -1;
		}
	}
    // 打开音频编码器
	if (avcodec_open2(avCodecContext, codec, NULL) < 0) {
		LOGI("Couldn't open codec");
		return -2;
	}
    // 时间戳基本单位设置（分数表示）
	avCodecContext->time_base.num = 1; // 分子
	avCodecContext->time_base.den = avCodecContext->sample_rate; // 分母
    // 帧大小
	avCodecContext->frame_size = 1024;
	return 0;
}

#pragma mark - 生成音频帧
int AudioEncoder::alloc_avframe() {
	int ret = 0;
    // 偏好音频格式配置
	AVSampleFormat preferedSampleFMT = AV_SAMPLE_FMT_S16;
	int preferedChannels = audioChannels;
	int preferedSampleRate = audioSampleRate;
    // 创建输入音频帧
	input_frame = av_frame_alloc();
	if (!input_frame) {
		LOGI("Could not allocate audio frame\n");
		return -1;
	}
	input_frame->nb_samples = avCodecContext->frame_size;
	input_frame->format = preferedSampleFMT;
	input_frame->channel_layout = preferedChannels == 1 ? AV_CH_LAYOUT_MONO : AV_CH_LAYOUT_STEREO;
	input_frame->sample_rate = preferedSampleRate;
    // 获取缓冲大小
    ret = av_samples_get_buffer_size(NULL, // 行宽
                                     av_get_channel_layout_nb_channels(input_frame->channel_layout), // 声道数
                                     input_frame->nb_samples, // 该帧描述的音频样本(每个通道)的数量
                                     preferedSampleFMT, // 样本格式
                                     0); // 缓冲大小对齐(0 - 默认, 1 - 不对齐)
    if (ret >= 0) {
        buffer_size = ret;
    } else {
        LOGI("get buffer size error %d.\n", ret);
    }
    // 申请样本内存
	samples = (uint8_t*)av_malloc(buffer_size);
    // 重置指针
	samplesCursor = 0;
	if (!samples) {
		LOGI("Could not allocate %d bytes for samples buffer\n", buffer_size);
		return -2;
	}
	LOGI("allocate %d bytes for samples buffer\n", buffer_size);
    // 配置音频帧
	/* setup the data pointers in the AVFrame */
	ret = avcodec_fill_audio_frame(input_frame, // the AVFrame frame->nb_samples must be set prior to calling the function. This function fills in frame->data, frame->extended_data, frame->linesize[0].
                                   av_get_channel_layout_nb_channels(input_frame->channel_layout), // 输入帧声道数
                                   preferedSampleFMT, // 样本格式
                                   samples, // 样本
                                   buffer_size, // 缓冲大小
                                   0); // plane size sample alignment (0 = default)
	if (ret < 0) {
		LOGI("Could not setup audio frame\n");
	}
    // 需要重采样的情况
	if(swrContext) {
		if (av_sample_fmt_is_planar(avCodecContext->sample_fmt)) {
			LOGI("Codec Context SampleFormat is Planar...");
		}
		/* 分配空间 */
		convert_data = (uint8_t**)calloc(avCodecContext->channels,
                                         sizeof(*convert_data));
		av_samples_alloc(convert_data,
                         NULL,
                         avCodecContext->channels,
                         avCodecContext->frame_size,
                         avCodecContext->sample_fmt, 0);
		swrBufferSize = av_samples_get_buffer_size(NULL,
                                                   avCodecContext->channels,
                                                   avCodecContext->frame_size,
                                                   avCodecContext->sample_fmt,
                                                   0);
		swrBuffer = (uint8_t *)av_malloc(swrBufferSize);
		LOGI("After av_malloc swrBuffer");
		/* 此时data[0],data[1]分别指向frame_buf数组起始、中间地址 */
		swrFrame = av_frame_alloc();
		if (!swrFrame) {
			LOGI("Could not allocate swrFrame frame\n");
			return -1;
		}
		swrFrame->nb_samples = avCodecContext->frame_size;
		swrFrame->format = avCodecContext->sample_fmt;
		swrFrame->channel_layout = avCodecContext->channels == 1 ? AV_CH_LAYOUT_MONO : AV_CH_LAYOUT_STEREO;
		swrFrame->sample_rate = avCodecContext->sample_rate;
		ret = avcodec_fill_audio_frame(swrFrame, avCodecContext->channels, avCodecContext->sample_fmt, (const uint8_t*)swrBuffer, swrBufferSize, 0);
		LOGI("After avcodec_fill_audio_frame");
		if (ret < 0) {
			LOGI("avcodec_fill_audio_frame error ");
		    return -1;
		}
	}
	return ret;
}

#pragma mark - 初始化方法
int AudioEncoder::init(int bitRate,
                       int channels,
                       int sampleRate,
                       int bitsPerSample,
                       const char * aacFilePath,
                       const char * codec_name) {
    // 属性初始化
	avCodecContext = NULL;
	avFormatContext = NULL;
	input_frame = NULL;
	samples = NULL;
	samplesCursor = 0;
	swrContext = NULL;
	swrFrame = NULL;
	swrBuffer = NULL;
	convert_data = NULL;
	this->isWriteHeaderSuccess = false;
	totalEncodeTimeMills = 0;
	totalSWRTimeMills = 0;
	this->publishBitRate = bitRate;
	this->audioChannels = channels;
	this->audioSampleRate = sampleRate;
    
    int ret = 0;
    // 注册所有编码器、解码器和比特流过滤器
    avcodec_register_all();
    // 初始化libavformat并注册所有的muxer、demuxer和协议
    av_register_all();
    
    // 创建 avformat 上下文
    avFormatContext = avformat_alloc_context();
    // 读取文件的格式信息
    ret = avformat_alloc_output_context2(&avFormatContext, NULL, NULL, aacFilePath);
    if (ret < 0) {
        LOGI("avFormatContext alloc failed : %s", av_err2str(ret));
        return -1;
    }

    LOGI("aacFilePath is %s ", aacFilePath);
    /**
     * 作用：打开文件链接通道
     * decoding: 在 avformat_open_input() 之前调用
     * encoding: 在 avformat_write_header() 之前调用（主要用于AVFMT_NOFILE格式）
     * 如果回调用于打开文件，也应该通过使用 avio_open2()。
     */
    ret = avio_open2(&avFormatContext->pb, aacFilePath, AVIO_FLAG_WRITE, NULL, NULL);
	if (ret < 0) {
		LOGI("Could not avio open fail %s", av_err2str(ret));
		return -1;
	}

    // 根据编码名称生成音频流
	this->alloc_audio_stream(codec_name);
    
    // 打印关于输入或输出格式的详细信息，
    // 如持续时间、比特率、流、容器、程序、元数据、边数据、编解码器和时间基点。
	av_dump_format(avFormatContext, 0, aacFilePath, 1);
    
    // 编写文件头
    int headerRet = avformat_write_header(avFormatContext, NULL);
	if (headerRet < 0) {
		LOGI("Could not write header\n");
		return -1;
	}
    // 标记编写头文件成功
	this->isWriteHeaderSuccess = true;
    // 生成音频帧
	this->alloc_avframe();
	return 1;
}

int AudioEncoder::init(int bitRate,
                       int channels,
                       int bitsPerSample,
                       const char* aacFilePath,
                       const char * codec_name) {
	return init(bitRate, channels, 44100, bitsPerSample, aacFilePath, codec_name);
}

#pragma mark - 编码方法
void AudioEncoder::encode(byte* buffer, int size) {
	int bufferCursor = 0; // 当前局部处理进度指针
	int bufferSize = size; // 缓冲大小
	while (bufferSize >= (buffer_size - samplesCursor)) {
		int cpySize = buffer_size - samplesCursor;
		memcpy(samples + samplesCursor, buffer + bufferCursor, cpySize);
		bufferCursor += cpySize;
		bufferSize -= cpySize;
		this->encodePacket();
		samplesCursor = 0;
	}
	if (bufferSize > 0) {
		memcpy(samples + samplesCursor, buffer + bufferCursor, bufferSize);
		samplesCursor += bufferSize;
	}
}

#pragma mark - 编码打包
void AudioEncoder::encodePacket() {
	LOGI("begin encode packet..................");
	int ret;
    // 初始化音频包
	AVPacket pkt;
	av_init_packet(&pkt);
    // 编码帧
	AVFrame* encode_frame;
    // 编码帧数据填充
	if (swrContext) {
        // 对当前数据进行重采样(转换)
		swr_convert(swrContext, // allocated Swr context, with parameters set
                    convert_data, // 输出数据
                    avCodecContext->frame_size, // 输出数据的大小（帧大小）
                    (const uint8_t**)input_frame->data, // 输入帧数据
                    avCodecContext->frame_size); // 输入数据的大小（帧大小）
        // 总长度
		int length = avCodecContext->frame_size * av_get_bytes_per_sample(avCodecContext->sample_fmt);
		for (int k = 0; k < 2; ++k) { // 双声道读取
			for (int j = 0; j < length; ++j) {
				swrFrame->data[k][j] = convert_data[k][j];
		    }
		}
		encode_frame = swrFrame;
	} else {
		encode_frame = input_frame;
	}
    // 包配置
	pkt.stream_index = 0;
	pkt.duration = (int)AV_NOPTS_VALUE;
	pkt.pts = pkt.dts = 0;
	pkt.data = samples;
	pkt.size = buffer_size;
    
    // avcodec_encode_audio2 替换为 avcodec_send_frame & avcodec_receive_packet
    // int avcodec_send_frame(AVCodecContext *avctx, const AVFrame *frame);
    // 向编码器发送编码帧
    ret = avcodec_send_frame(avCodecContext, encode_frame);
    if (ret != 0) {
        LOGI("send frame to avcode fail : %s", av_err2str(ret));
    }
    // int avcodec_receive_packet(AVCodecContext *avctx, AVPacket *avpkt);
    // 接收编码器编码后的包
    ret = avcodec_receive_packet(avCodecContext, &pkt);
    if (ret != 0) {
        LOGI("receive packet from avcode fail : %s", av_err2str(ret));
    } else {
        if (avCodecContext->coded_frame &&
            avCodecContext->coded_frame->pts != AV_NOPTS_VALUE)
            pkt.pts = av_rescale_q(avCodecContext->coded_frame->pts,
                                   avCodecContext->time_base,
                                   audioStream->time_base);
        pkt.flags |= AV_PKT_FLAG_KEY;
        this->duration = pkt.pts * av_q2d(audioStream->time_base);
        
        // 此函数负责交错地输出一个媒体包。
        // 如果调用者无法保证来自各个媒体流的包正确交错，则最好调用此函数输出媒体包，
        // 反之，可以调用av_write_frame以提高性能。
        int writeCode = av_interleaved_write_frame(avFormatContext, &pkt);
        if (writeCode != 0) {
            LOGI("write frame to file fail : %s", av_err2str(writeCode));
        }
    }
    
    av_packet_unref(&pkt);
	LOGI("leave encode packet...");
}

#pragma mark - 销毁
void AudioEncoder::destroy() {
	LOGI("start destroy!!!");
	//这里需要判断是否删除resampler(重采样音频格式/声道/采样率等)相关的资源
	if (NULL != swrBuffer) {
		free(swrBuffer);
		swrBuffer = NULL;
		swrBufferSize = 0;
	}
	if (NULL != swrContext) {
		swr_free(&swrContext);
		swrContext = NULL;
	}
	if(convert_data) {
		av_freep(&convert_data[0]);
		free(convert_data);
	}
	if (NULL != swrFrame) {
		av_frame_free(&swrFrame);
	}
	if (NULL != samples) {
		av_freep(&samples);
	}
	if (NULL != input_frame) {
		av_frame_free(&input_frame);
	}
	if(this->isWriteHeaderSuccess) {
		avFormatContext->duration = this->duration * AV_TIME_BASE;
	    LOGI("duration is %.3f", this->duration);
	    av_write_trailer(avFormatContext);
	}
	if (NULL != avCodecContext) {
		avcodec_close(avCodecContext);
		av_free(avCodecContext);
	}
	if (NULL != avCodecContext && NULL != avFormatContext->pb) {
		avio_close(avFormatContext->pb);
	}
	LOGI("end destroy!!! totalEncodeTimeMills is %d totalSWRTimeMills is %d", totalEncodeTimeMills, totalSWRTimeMills);
}
