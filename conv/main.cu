#include <stdio.h>

static void HandleError(cudaError_t err,const char * file,int line){
    if(err!=cudaSuccess){
        printf("%s in %s at line %d\n",cudaGetErrorString(err),file,line);
        exit(EXIT_FAILURE);
    }
}

#define HANDLE_ERROR(err) (HandleError(err,__FILE__,__LINE__))

int getThreadNum(){
    cudaDeviceProp prop;
    int count;
    HANDLE_ERROR(cudaGetDeviceCount(&count));
    printf("gpu num %d\n",count);
    HANDLE_ERROR(cudaGetDeviceProperties(&prop,0));
    printf("max thread num:%d\n",prop.maxThreadsPerBlock);
    printf("max grid dimensions:%d %d %d\n",prop.maxGridSize[0],prop.maxGridSize[1],prop.maxGridSize[2]);
    return prop.maxThreadsPerBlock;
}

__global__ void conv(float *img,float *kernel,float *result,int width,int height,int kernelSize){
    int ti=threadIdx.x;
    int bi=blockIdx.x;
    int id=bi*blockDim.x+ti;
    if(id>=width*height){
        return ;
    }
    int row=id/width,col=id%width;
    for(int i=0;i<kernelSize;i++){
        for(int j=0;j<kernelSize;j++){
            float imgValue=0;
            int curRow=row-kernelSize/2+i;
            int curCol=col-kernelSize/2+j;
            if(curRow<0||curCol<0||curRow>=height||curCol>=width){
                    ;
            }else{
                imgValue=img[curRow*width+curCol];
            }
            result[id]+=kernel[i*kernelSize+j]*imgValue;
        }
    }
}
int main(){
    int width=10;
    int height=10;
    float *img=new float[width*height];
    for(int i=0;i<height;i++){
        for(int j=0;j<width;j++){
            img[j+i*width]=(i+j)%256;
        }
    }

    int kernelSize=3;
    float *kernel=new float[kernelSize*kernelSize];
    for(int i=0;i<kernelSize*kernelSize;i++){
        kernel[i]=i%kernelSize-1;
    }

    float *imgGpu,*kernelGpu,*resultGpu;

    HANDLE_ERROR(cudaMalloc((void**)&imgGpu,width*height*sizeof(float)));
    HANDLE_ERROR(cudaMalloc((void**)&kernelGpu,kernelSize*kernelSize*sizeof(float)));
    HANDLE_ERROR(cudaMalloc((void**)&resultGpu,width*height*sizeof(float)));

    HANDLE_ERROR(cudaMemcpy(imgGpu,img,width*height*sizeof(float),cudaMemcpyHostToDevice));
    HANDLE_ERROR(cudaMemcpy(kernelGpu,kernel,kernelSize*kernelSize*sizeof(float),cudaMemcpyHostToDevice));

    int threadNum=getThreadNum();
    int blockNum=(width*height-0.5)/threadNum+1;
    conv<<<blockNum,threadNum>>>(imgGpu,kernelGpu,resultGpu,width,height,kernelSize);

    float *result=new float[width*height];
    HANDLE_ERROR(cudaMemcpy(result,resultGpu,width*height*sizeof(float),cudaMemcpyDeviceToHost));
    //Visualization
    printf("img:\n");
    for(int i=0;i<10;i++){
        for(int j=0;j<10;j++){
            printf("%2.0f ",img[j+i*width]);
        }
        puts("");
    }
    printf("kernel:\n");
    for(int i=0;i<kernelSize;i++){
        for(int j=0;j<kernelSize;j++){
            printf("%2.0lf ",kernel[i*kernelSize+j]);
        }
        puts("");
    }
    printf("result:\n");
    for(int i=0;i<10;i++){
        for(int j=0;j<10;j++){
            printf("%2.0f ",result[j+i*width]);
        }
        puts("");
    }
    return 0;
}