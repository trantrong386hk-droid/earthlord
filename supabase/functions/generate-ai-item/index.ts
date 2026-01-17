// supabase/functions/generate-ai-item/index.ts
//
// AI 物品生成 Edge Function
// 调用阿里云百炼 qwen-flash 模型生成独特的物品名称和背景故事
//

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import OpenAI from "npm:openai";

// 阿里云百炼配置（必须使用国际版端点）
const openai = new OpenAI({
    apiKey: Deno.env.get("DASHSCOPE_API_KEY"),
    baseURL: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
});

// 系统提示词
const SYSTEM_PROMPT = `你是一个末日生存游戏的物品生成器。

根据搜刮地点生成物品列表，每个物品包含：
- name: 独特名称（15字以内）
- category: 分类（医疗/食物/工具/武器/材料）
- rarity: 稀有度（common/uncommon/rare/epic/legendary）
- story: 背景故事（50-100字）

规则：
1. 物品类型要与地点相关
2. 名称要有创意，暗示前主人或来历
3. 故事要有画面感，营造末日氛围
4. 可以有黑色幽默

只返回 JSON 数组，不要其他内容。`;

// 根据危险值生成稀有度分布
function getRarityWeights(dangerLevel: number) {
    switch (dangerLevel) {
        case 1:
        case 2:
            return { common: 70, uncommon: 25, rare: 5, epic: 0, legendary: 0 };
        case 3:
            return { common: 50, uncommon: 30, rare: 15, epic: 5, legendary: 0 };
        case 4:
            return { common: 0, uncommon: 40, rare: 35, epic: 20, legendary: 5 };
        case 5:
            return { common: 0, uncommon: 0, rare: 30, epic: 40, legendary: 30 };
        default:
            return { common: 60, uncommon: 30, rare: 10, epic: 0, legendary: 0 };
    }
}

Deno.serve(async (req: Request) => {
    // CORS 处理
    if (req.method === "OPTIONS") {
        return new Response(null, {
            headers: {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization",
            },
        });
    }

    try {
        const { poi, itemCount = 3 } = await req.json();

        console.log(`[generate-ai-item] POI: ${poi.name}, Type: ${poi.type}, Danger: ${poi.dangerLevel}, Count: ${itemCount}`);

        const rarityWeights = getRarityWeights(poi.dangerLevel);

        const userPrompt = `搜刮地点：${poi.name}（${poi.type}类型，危险等级 ${poi.dangerLevel}/5）

请生成 ${itemCount} 个物品。

稀有度分布参考：
- 普通(common): ${rarityWeights.common}%
- 优秀(uncommon): ${rarityWeights.uncommon}%
- 稀有(rare): ${rarityWeights.rare}%
- 史诗(epic): ${rarityWeights.epic}%
- 传奇(legendary): ${rarityWeights.legendary}%

返回 JSON 数组格式。`;

        const completion = await openai.chat.completions.create({
            model: "qwen-flash",
            messages: [
                { role: "system", content: SYSTEM_PROMPT },
                { role: "user", content: userPrompt }
            ],
            max_tokens: 800,
            temperature: 0.8
        });

        const content = completion.choices[0]?.message?.content || "[]";
        console.log(`[generate-ai-item] Raw response: ${content.substring(0, 200)}...`);

        // 清理可能的 markdown 代码块
        const cleanContent = content.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
        const items = JSON.parse(cleanContent);

        console.log(`[generate-ai-item] Generated ${items.length} items`);

        return new Response(
            JSON.stringify({ success: true, items }),
            {
                headers: {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                }
            }
        );

    } catch (error) {
        console.error("[generate-ai-item] Error:", error);
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            {
                status: 500,
                headers: {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                }
            }
        );
    }
});
