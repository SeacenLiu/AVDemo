#ifndef RGBA_FRAME_H
#define RGBA_FRAME_H

#ifdef __cplusplus
#include <string>
#endif

// RGBA 帧数据（主要保存像素信息）
class RGBAFrame {
public:
	float position;
	float duration;
	uint8_t * pixels;
	int width;
	int height;
	RGBAFrame();
	~RGBAFrame();
	RGBAFrame* clone();
};

#endif /* RGBA_FRAME_H */

