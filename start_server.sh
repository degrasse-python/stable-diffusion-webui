
# raise the mps high watermark to 70% to avoid OOM
PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.7 ./webui.sh --precision full --no-half