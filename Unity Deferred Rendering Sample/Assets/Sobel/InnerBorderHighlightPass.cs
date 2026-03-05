using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class InnerBorderHighlightPass : ScriptableRenderPass
{
    private InnerBorderHighlightFeature.Settings _settings;
    private Material _mat;
    private RTHandle _tempRT;

    // Shader Property ID 캐싱
    private static readonly int BorderColorId = Shader.PropertyToID("_BorderColor");
    private static readonly int DepthThresholdId = Shader.PropertyToID("_DepthThreshold");
    private static readonly int AlbedoMixId = Shader.PropertyToID("_AlbedoMix");
    private static readonly int BorderWidthId = Shader.PropertyToID("_AlbedoMix");

    public InnerBorderHighlightPass(InnerBorderHighlightFeature.Settings settings)
    {
        _settings = settings;
        _mat = CoreUtils.CreateEngineMaterial("Custom/InnerBorderHighlight");

        // Depth 텍스처 요청 (ConfigureInput으로 명시해야 URP가 준비해줌)
        ConfigureInput(ScriptableRenderPassInput.Depth);
    }

    public void SetupSettings(InnerBorderHighlightFeature.Settings settings)
    {
        _settings = settings;
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        // 임시 RT 할당 (카메라 해상도에 맞춤)
        var desc = renderingData.cameraData.cameraTargetDescriptor;
        desc.depthBufferBits = 0; // 컬러 RT니까 depth 불필요
        RenderingUtils.ReAllocateIfNeeded(ref _tempRT, desc, name: "_InnerBorderTemp");
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (_mat == null) return;

        var cmd = CommandBufferPool.Get("InnerBorderHighlight");

        // 쉐이더 파라미터 설정
        _mat.SetColor(BorderColorId, _settings.borderColor);
        _mat.SetFloat(DepthThresholdId, _settings.depthThreshold);
        _mat.SetFloat(AlbedoMixId, _settings.albedoMix);
        _mat.SetFloat(BorderWidthId, _settings.borderWidth);

        var srcHandle = renderingData.cameraData.renderer.cameraColorTargetHandle;

        // 1. 카메라 색상 -> 임시 RT (Sobel + 합성 처리)
        Blitter.BlitCameraTexture(cmd, srcHandle, _tempRT, _mat, 0);
        // 2. 임시 RT -> 카메라 색상 (결과 복사)
        Blitter.BlitCameraTexture(cmd, _tempRT, srcHandle);

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public override void OnCameraCleanup(CommandBuffer cmd) { }

    public void Dispose()
    {
        _tempRT?.Release();
        CoreUtils.Destroy(_mat);
    }
}