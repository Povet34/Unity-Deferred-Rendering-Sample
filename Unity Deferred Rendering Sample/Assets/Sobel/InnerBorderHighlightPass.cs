using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class InnerBorderHighlightPass : ScriptableRenderPass
{
    private InnerBorderHighlightFeature.Settings _settings;
    private Material _mat;
    private RTHandle _tempRT;

    private static readonly int BorderColorId = Shader.PropertyToID("_BorderColor");
    private static readonly int DepthThresholdId = Shader.PropertyToID("_DepthThreshold");
    private static readonly int AlbedoMixId = Shader.PropertyToID("_AlbedoMix");
    private static readonly int BorderWidthId = Shader.PropertyToID("_BorderWidth");

    public InnerBorderHighlightPass(InnerBorderHighlightFeature.Settings settings)
    {
        _settings = settings;
        _mat = CoreUtils.CreateEngineMaterial("Custom/InnerBorderHighlight");
        ConfigureInput(ScriptableRenderPassInput.Depth);
    }

    public void SetupSettings(InnerBorderHighlightFeature.Settings settings)
    {
        _settings = settings;
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        var desc = renderingData.cameraData.cameraTargetDescriptor;
        desc.depthBufferBits = 0;
        RenderingUtils.ReAllocateIfNeeded(ref _tempRT, desc, name: "_InnerBorderTemp");
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (_mat == null) return;

        var cmd = CommandBufferPool.Get("InnerBorderHighlight");

        _mat.SetColor(BorderColorId, _settings.borderColor);
        _mat.SetFloat(DepthThresholdId, _settings.depthThreshold);
        _mat.SetFloat(AlbedoMixId, _settings.albedoMix);
        _mat.SetFloat(BorderWidthId, _settings.borderWidth);

        var src = renderingData.cameraData.renderer.cameraColorTargetHandle;
        Blitter.BlitCameraTexture(cmd, src, _tempRT, _mat, 0);
        Blitter.BlitCameraTexture(cmd, _tempRT, src);

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