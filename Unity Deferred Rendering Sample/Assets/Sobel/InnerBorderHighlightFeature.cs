using UnityEngine;
using UnityEngine.Rendering.Universal;

public class InnerBorderHighlightFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        [Header("Border")]
        public Color borderColor = Color.white;
        [Range(0f, 10f)] public float depthThreshold = 1f;
        [Range(0f, 1f)] public float albedoMix = 0.5f;
        [Range(1f, 10f)] public float borderWidth = 1f;
    }

    public Settings settings = new Settings();
    private InnerBorderHighlightPass _pass;

    public override void Create()
    {
        _pass = new InnerBorderHighlightPass(settings)
        {
            renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (renderingData.cameraData.cameraType != CameraType.Game) return;
        _pass.SetupSettings(settings);
        renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {
        _pass?.Dispose();
    }
}