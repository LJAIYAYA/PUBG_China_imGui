//
//  ESP.m
//  PUBG
//
//  Created by 十三哥 on 2023/5/31.
//
#import <shisangeIMGUI/imgui_impl_metal.h>
#import <shisangeIMGUI/imgui.h>
#import <dispatch/dispatch.h>
#import "ESP.h"
#import "gameVM.h"
#import "PUBGDataModel.h"
#import "PUBGTypeHeader.h"
#import "YMUIWindow.h"
#import "ShiSnGeWindow.h"
#include <vector>
#include <unordered_map>
#include <random>
#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height

#pragma mark - 绘制函数
//绘制线条
static void DrawLine(ImVec2 startPoint, ImVec2 endPoint, int color, float thicknes = 1)
{
    ImGui::GetOverlayDrawList()->AddLine(startPoint, endPoint, color, thicknes);
}
//绘制文字
static void DrawText(std::string text, ImVec2 pos, bool isCentered, int color, bool outline, float fontSize)
{
    const char *str = text.c_str();
    ImVec2 vec2 = pos;
    
    if (isCentered) {
        ImFont* font = ImGui::GetFont();
        font->Scale = 16 / font->FontSize;
        
        ImVec2 textSize = font->CalcTextSizeA(fontSize, MAXFLOAT, 0.0f, str);
        vec2.x -= textSize.x * 0.5f;
    }
    if (outline)
    {
        ImU32 outlineColor = 0xFF000000;
        ImGui::GetOverlayDrawList()->AddText(ImGui::GetFont(), fontSize, ImVec2(vec2.x + 1, vec2.y + 1), outlineColor, str);
        ImGui::GetOverlayDrawList()->AddText(ImGui::GetFont(), fontSize, ImVec2(vec2.x - 1, vec2.y - 1), outlineColor, str);
        ImGui::GetOverlayDrawList()->AddText(ImGui::GetFont(), fontSize, ImVec2(vec2.x + 1, vec2.y - 1), outlineColor, str);
        ImGui::GetOverlayDrawList()->AddText(ImGui::GetFont(), fontSize, ImVec2(vec2.x - 1, vec2.y + 1), outlineColor, str);
    }
    ImGui::GetOverlayDrawList()->AddText(ImGui::GetFont(), fontSize, vec2, color, str);
}
//绘制扇形
static void DrawSector(ImDrawList* drawList, const ImVec2& center, float radius, float fromAngle, float toAngle, ImU32 color, int num_segments)
{
    const float PI = 3.14159265358979323846f;
    
    // 计算角度
    fromAngle = fromAngle * PI / 180.0f;
    toAngle = toAngle * PI / 180.0f;
    
    // 计算每段的增量角
    float deltaAngle = (toAngle - fromAngle) / (float)num_segments;
    
    // 添加中心顶点
    drawList->PathLineTo(center);
    
    // 添加弧顶点
    for (int i = 0; i <= num_segments; ++i)
    {
        float angle = fromAngle + deltaAngle * (float)i;
        ImVec2 pos(center.x + radius * cosf(angle), center.y + radius * sinf(angle));
        drawList->PathLineTo(pos);
    }
    
    //关闭路径
    drawList->PathFillConvex(color);
}

#pragma mark - 初始化全局变量 开关 颜色 搭配.h里面用extern作为全局变量 方便菜单那边读取和赋值
bool  绘制总开关,过直播开关, 无后座开关,自瞄开关,追踪开关,手雷预警开关;
bool  射线开关,骨骼开关,方框开关,距离开关,血条开关,名字开关,背景开关,边缘开关,附近人数开关,手持武器开关;
bool  物资总开关,载具开关,药品开关,投掷物开关,枪械开关,配件开关,子弹开关,其他物资开关,高级物资开关,倍镜开关,头盔开关,护甲开关,背包开关,物资调试开关;
float 追踪距离;
float 追踪圆圈;
int 追踪部位;
float 自瞄速度;
//初始化颜色
ImVec4 血条颜色 = ImVec4(1.0f, 0.0f, 0.0f, 1.0f);
ImVec4 方框颜色 = ImVec4(0.0f, 1.0f, 0.0f, 1.0f);
ImVec4 射线颜色 = ImVec4(1.0f, 1.0f, 0.0f, 1.0f);
ImVec4 骨骼颜色 = ImVec4(1.0f, 1.0f, 0.0f, 1.0f);
ImVec4 距离颜色 = ImVec4(0.0f, 1.0f, 0.0f, 1.0f);
ImVec4 手持武器颜色 = ImVec4(0.0f, 1.0f, 0.0f, 1.0f);
ImVec4 名字颜色 = ImVec4(1.0f, 1.0f, 1.0f, 1.0f);
ImVec4 背景颜色 = ImVec4(0.0f, 1.0f, 1.0f, 1.0f);

#pragma mark - 初始化队伍颜色向量
// 更具对标生成不同颜色
std::unordered_map<int, ImVec4> team_colors;
static ImVec4 GetTeamColor(int team_id)
{
    // Check if the team color already exists in the map
    auto it = team_colors.find(team_id);
    if (it != team_colors.end()) {
        return it->second;
    }
    
    // Generate a new random color for the team
    
    static std::random_device rd;
    static std::mt19937 rng(rd());
    std::uniform_real_distribution<float> dist(0.0f, 1.0f);
    ImVec4 color(dist(rng), dist(rng), dist(rng), 1.0f);
    
    // Add the new color to themap
    team_colors.insert(std::make_pair(team_id, color));
    
    return color;
}
//清空每局游戏结束清空
static void EndGame()
{
    team_colors.clear();
}

#pragma mark - ESP

@implementation ESP{
    dispatch_source_t timer;
}
#pragma mark - 单例
+ (instancetype)sharedInstance {
    static ESP *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] initWithFrame:[YMUIWindow sharedInstance].bounds];
    });
    return sharedInstance;
}
#pragma mark - 当前页面视图初始化
- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
    }
    return self;
}

#pragma mark - 绘制玩家
//绘制玩家

- (void)绘制玩家:(ImDrawList*)MsDrawList{
    //创建单例 每秒读取一次玩家数组
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // 创建 GCD定时器
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        
        // 设置定时器的执行时间间隔、起始时间和精度
        uint64_t interval = 2 * NSEC_PER_SEC; // 时间间隔为2秒
        uint64_t leeway = 0 * NSEC_PER_SEC; // 定时器的精度为0秒
        dispatch_time_t startTime = dispatch_time(DISPATCH_TIME_NOW, 0);
        dispatch_source_set_timer(timer, startTime, interval, leeway);
        
        // 设置定时器的执行任务
        dispatch_source_set_event_handler(timer, ^{
            // 定时器每执行一次，就会调用这个 block 中的代码
            //多线程
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                //回到主线程的方法
                [[gameVM sharedInstance] CacheData];//每秒读取一次玩家数组
                
            });
            
            
        });
        
        // 启动定时器
        dispatch_resume(timer);
        
    });
    
    //开始读取数据和绘制
    [[gameVM sharedInstance] getData:^(NSArray * _Nonnull playerArray, NSArray * _Nonnull wzArray) {
        if (附近人数开关) {
            NSString *resnhustr;
            if (playerArray.count == 0) {
                EndGame();//清空队伍颜色
                resnhustr = @"安全";
            } else {
                resnhustr = [NSString stringWithFormat:@"%ld", playerArray.count];
            }
            const char *cString = [resnhustr cStringUsingEncoding:NSUTF8StringEncoding];
            DrawText(cString, ImVec2(kWidth/2 , 10), true, ImColor(ImVec4(1.0f, 0.0f, 0.0f, 1.0f)), false, 20);
        }
        //绘制玩家
        for (NSInteger i = 0; i < playerArray.count; i++) {
            PUBGPlayerModel *model = playerArray[i];
            static CGFloat x = 0;
            static CGFloat y = 0;
            static CGFloat w = 0;
            static CGFloat h = 0;
            //开始绘制 解析玩家方框
            x = model.rect.X;
            y = model.rect.Y;
            w = model.rect.W;
            h = model.rect.H;
            float xd = x+w/2;
            float yd = y;
            //屏幕外面 只绘制射线然后跳出 执行下一个玩家 避免绘制其他占用内存CPU===============
            if (model.isPm==NO){
                if(射线开关){
                    MsDrawList->AddLine(ImVec2(kWidth/2, 40), ImVec2(xd, yd-40),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 射线颜色 ),1);
                }
                continue;
            }
            
            
            //屏幕里面 由开关控制绘制内容=======================
            //射线
            if(射线开关){
                MsDrawList->AddLine(ImVec2(kWidth/2, 40), ImVec2(xd, yd-40),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 射线颜色 ),1);
            }
            if(追踪开关){
                MsDrawList->AddCircle(ImVec2(kWidth/2, kHeight/2), 追踪圆圈, ImColor(射线颜色));
            }
            
            if(背景开关){
                //信息背景
                ImVec4 背景颜色 = GetTeamColor(model.TeamID);
                MsDrawList->AddLine(ImVec2(xd-40,yd-16), ImVec2(xd+40,yd-16), ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 背景颜色 ),13);
                
                //对标背景
                MsDrawList->AddLine(ImVec2(xd-40,yd-16), ImVec2(xd-25,yd-16), ImColor(ImVec4(1.0f, 0.0f, 1.0f, 0.7f)),14);
            }
            if (名字开关) {
                //名字
                char* ii = (char*) [model.PlayerName cStringUsingEncoding:NSUTF8StringEncoding];
                DrawText(ii, ImVec2(xd+10 , y-21), true, ImColor(名字颜色), false, 10);
                
                //对标
                char* i = (char*) [[NSString stringWithFormat:@"%d",model.TeamID] cStringUsingEncoding:NSUTF8StringEncoding];
                DrawText(i, ImVec2(xd-30 , y-21), true, ImColor(ImVec4(1.0f, 1.0f, 0.0f, 1.0f)), false, 10);
            }
            if(距离开关){
                //距离
                char* juli = (char*) [[NSString stringWithFormat:@"%dm",(int)model.Distance] cStringUsingEncoding:NSUTF8StringEncoding];
                DrawText(juli, ImVec2(xd+20, yd-35), true, ImColor(距离颜色), false, 12);
            }
            
            if(血条开关){
                //血条背景
                MsDrawList->AddLine(ImVec2(xd-40,yd-9), ImVec2(xd+40,yd-9), ImColor(0xFFFFFFFF),3);//白色
                //血条
                MsDrawList->AddLine(ImVec2(xd-40,yd-9), ImVec2(xd-40+0.8*model.Health,yd-9), ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 血条颜色 ),3);
            }
            
            if (手持武器开关) {
                char* dis = (char*) [[NSString stringWithFormat:@"%@",model.WeaponName] cStringUsingEncoding:NSUTF8StringEncoding];
                DrawText(dis, ImVec2(xd-20, yd-35), true, ImColor(ImVec4(1.0f, 1.0f, 1.0f, 1.0f)), false, 10);
            }
            
            if(方框开关){
                for (int i = 0; i < 4; i++) {
                    float x1, y1, x2, y2;
                    switch (i) {
                        case 0: // 左上角
                            x1 = x;
                            y1 = y;
                            x2 = x - w / 2;
                            y2 = y;
                            break;
                        case 1: // 右上角
                            x1 = x + w * 0.75;
                            y1 = y;
                            x2 = x + w * 1.25;
                            y2 = y;
                            break;
                        case 2: // 左下角
                            x1 = x;
                            y1 = y + h + 4;
                            x2 = x - w / 2;
                            y2 = y + h + 4;
                            break;
                        case 3: // 右下角
                            x1 = x + w * 0.75;
                            y1 = y + h + 4;
                            x2 = x + w * 1.25;
                            y2 = y + h + 4;
                            break;
                    }
                    MsDrawList->AddLine(ImVec2(x1, y1), ImVec2(x2, y2), ImColor(方框颜色), 1);
                    
                }
                
            }
            if (骨骼开关) {
                //躯干
                DrawLine(ImVec2(model._0.X, model._0.Y),ImVec2(model._1.X, model._1.Y),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 骨骼颜色), 1);
                DrawLine(ImVec2(model._1.X, model._1.Y),ImVec2(model._2.X, model._2.Y),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 骨骼颜色), 1);
                DrawLine(ImVec2(model._2.X, model._2.Y),ImVec2(model._3.X, model._3.Y),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 骨骼颜色), 1);
                DrawLine(ImVec2(model._3.X, model._3.Y),ImVec2(model._4.X, model._4.Y),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 骨骼颜色), 1);
                DrawLine(ImVec2(model._4.X, model._4.Y),ImVec2(model._5.X, model._5.Y),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 骨骼颜色), 1);
                
                //胸-有肩膀-右肘-右手
                DrawLine(ImVec2(model._2.X, model._2.Y),ImVec2(model._6.X, model._6.Y),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 骨骼颜色), 1);
                DrawLine(ImVec2(model._6.X, model._6.Y),ImVec2(model._7.X, model._7.Y),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 骨骼颜色), 1);
                DrawLine(ImVec2(model._7.X, model._7.Y),ImVec2(model._8.X, model._8.Y),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 骨骼颜色), 1);
                //
                //胸-腰-盆骨
                DrawLine(ImVec2(model._2.X, model._2.Y),ImVec2(model._9.X, model._9.Y),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 骨骼颜色), 1);
                DrawLine(ImVec2(model._9.X, model._9.Y),ImVec2(model._10.X, model._10.Y),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 骨骼颜色), 1);
                DrawLine(ImVec2(model._10.X, model._10.Y),ImVec2(model._11.X, model._11.Y),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 骨骼颜色), 1);
                
                //盆骨-左盆骨
                DrawLine(ImVec2(model._5.X, model._5.Y),ImVec2(model._12.X, model._12.Y),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 骨骼颜色), 1);
                //左盆骨-左膝盖
                DrawLine(ImVec2(model._12.X, model._12.Y),ImVec2(model._13.X, model._13.Y),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 骨骼颜色), 1);
                //左膝盖-左脚
                DrawLine(ImVec2(model._13.X, model._13.Y),ImVec2(model._14.X, model._14.Y),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 骨骼颜色), 1);
                
                //盆骨-右盆骨
                DrawLine(ImVec2(model._5.X, model._5.Y),ImVec2(model._15.X, model._15.Y),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 骨骼颜色), 1);
                //右盆骨-右膝盖
                DrawLine(ImVec2(model._15.X, model._15.Y),ImVec2(model._16.X, model._16.Y),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 骨骼颜色), 1);
                //右膝盖-右脚
                DrawLine(ImVec2(model._16.X, model._16.Y),ImVec2(model._17.X, model._17.Y),ImColor(model.isAI ? ImVec4(0.0f, 1.0f, 0.0f, 1.0f) : 骨骼颜色), 1);
            }
        }
        //绘制物资
        
        for (NSInteger i = 0; i < wzArray.count; i++){
            PUBGPlayerWZ *mode = wzArray[i];
            NSString*NewName=[NSString stringWithFormat:@"%@  %.1f",mode.Name,mode.JuLi];
            const char *cString = [NewName cStringUsingEncoding:NSUTF8StringEncoding];
            DrawText(cString, ImVec2(mode.WuZhi2D.X , mode.WuZhi2D.Y), true, ImColor(ImVec4(1.0f, 1.0f, 0.0f, 1.0f)), false, 10);
            
        }
        
    }];
    
}


@end