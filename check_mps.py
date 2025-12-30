import torch

def check_mps_availability():
    """
    Checks for the availability of MPS (Metal Performance Shaders) on this Mac.
    """
    print("--- MPS (Apple Silicon GPU) Availability Check ---")
    
    if not hasattr(torch.backends, "mps") or not torch.backends.mps.is_available():
        print("❌ MPS backend is not available on this device.")
        print("Please ensure you are running on a Mac with Apple Silicon and have the correct PyTorch version installed.")
        return False
    
    print("✅ MPS backend is available.")
    
    try:
        # Simple tensor operation to test MPS
        x = torch.tensor([1.0, 2.0, 3.0], device="mps")
        y = x * 2
        print("✅ Successfully created a tensor on the 'mps' device.")
        print(f"   - Input tensor: {x.cpu().numpy()}")
        print(f"   - Result of (tensor * 2): {y.cpu().numpy()}")
        return True
    except Exception as e:
        print(f"❌ An error occurred while testing the MPS device: {e}")
        return False

if __name__ == "__main__":
    check_mps_availability()
