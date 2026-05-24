import os
import shutil

def repack_clean():
    dtb_offset = 15131689
    original_gz_dtb_path = "ratibor_fresh/Image.gz-dtb"
    patched_dtb_path = "ratibor_patched.dtb"
    output_gz_dtb_path = "ratibor_fresh/Image.gz-dtb"
    
    print(f"Repackaging clean Ratibor kernel image. Reading original from {original_gz_dtb_path} up to offset {dtb_offset}...")
    if not os.path.exists(original_gz_dtb_path):
        print(f"Error: original kernel image not found at {original_gz_dtb_path}")
        return False
        
    with open(original_gz_dtb_path, "rb") as f:
        kernel_gz = f.read(dtb_offset)
        
    print(f"Reading patched DTB from {patched_dtb_path}...")
    if not os.path.exists(patched_dtb_path):
        print(f"Error: patched DTB not found at {patched_dtb_path}")
        return False
        
    with open(patched_dtb_path, "rb") as f:
        patched_dtb = f.read()
        
    print("Concatenating kernel payload and patched DTB...")
    new_image_gz_dtb = kernel_gz + patched_dtb
    
    # Save a backup of the original fresh file if it doesn't exist
    backup_path = original_gz_dtb_path + ".bak"
    if not os.path.exists(backup_path):
        shutil.copyfile(original_gz_dtb_path, backup_path)
        print(f"Created backup of original kernel image at {backup_path}")
        
    # Write the new repacked image
    with open(output_gz_dtb_path, "wb") as f_out:
        f_out.write(new_image_gz_dtb)
        
    print(f"Successfully wrote patched Image.gz-dtb to {output_gz_dtb_path} (size: {len(new_image_gz_dtb)} bytes)")
    return True

if __name__ == "__main__":
    repack_clean()
