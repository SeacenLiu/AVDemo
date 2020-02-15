varying highp vec2 v_texcoord;
uniform sampler2D inputImageTexture;

void main()
{
    gl_FragColor = texture2D(inputImageTexture, v_texcoord);
}
