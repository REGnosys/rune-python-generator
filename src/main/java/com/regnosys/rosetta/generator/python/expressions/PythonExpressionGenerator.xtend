package com.regnosys.rosetta.generator.python.expressions
import com.regnosys.rosetta.generator.java.enums.EnumHelper
import com.regnosys.rosetta.rosetta.RosettaCallableWithArgs
import com.regnosys.rosetta.rosetta.RosettaEnumValue
import com.regnosys.rosetta.rosetta.RosettaEnumValueReference
import com.regnosys.rosetta.rosetta.RosettaEnumeration
import com.regnosys.rosetta.rosetta.RosettaModel
import com.regnosys.rosetta.rosetta.expression.AsKeyOperation
import com.regnosys.rosetta.rosetta.expression.ChoiceOperation
import com.regnosys.rosetta.rosetta.expression.ClosureParameter
import com.regnosys.rosetta.rosetta.expression.DistinctOperation
import com.regnosys.rosetta.rosetta.expression.FilterOperation
import com.regnosys.rosetta.rosetta.expression.FirstOperation
import com.regnosys.rosetta.rosetta.expression.FlattenOperation
import com.regnosys.rosetta.rosetta.expression.LastOperation
import com.regnosys.rosetta.rosetta.expression.ListLiteral
import com.regnosys.rosetta.rosetta.expression.MapOperation
import com.regnosys.rosetta.rosetta.expression.ModifiableBinaryOperation
import com.regnosys.rosetta.rosetta.expression.Necessity
import com.regnosys.rosetta.rosetta.expression.OneOfOperation
import com.regnosys.rosetta.rosetta.expression.RosettaAbsentExpression
import com.regnosys.rosetta.rosetta.expression.RosettaBinaryOperation
import com.regnosys.rosetta.rosetta.expression.RosettaBooleanLiteral
import com.regnosys.rosetta.rosetta.expression.RosettaConditionalExpression
import com.regnosys.rosetta.rosetta.expression.RosettaConstructorExpression
import com.regnosys.rosetta.rosetta.expression.RosettaCountOperation
import com.regnosys.rosetta.rosetta.expression.RosettaExistsExpression
import com.regnosys.rosetta.rosetta.expression.RosettaExpression
import com.regnosys.rosetta.rosetta.expression.RosettaFeatureCall
import com.regnosys.rosetta.rosetta.expression.RosettaImplicitVariable
import com.regnosys.rosetta.rosetta.expression.RosettaIntLiteral
import com.regnosys.rosetta.rosetta.expression.RosettaNumberLiteral
import com.regnosys.rosetta.rosetta.expression.RosettaOnlyElement
import com.regnosys.rosetta.rosetta.expression.RosettaOnlyExistsExpression
import com.regnosys.rosetta.rosetta.expression.RosettaReference
import com.regnosys.rosetta.rosetta.expression.RosettaStringLiteral
import com.regnosys.rosetta.rosetta.expression.RosettaSymbolReference
import com.regnosys.rosetta.rosetta.expression.SortOperation
import com.regnosys.rosetta.rosetta.expression.SumOperation
import com.regnosys.rosetta.rosetta.expression.ThenOperation
import com.regnosys.rosetta.rosetta.expression.ToStringOperation
import com.regnosys.rosetta.rosetta.expression.ToDateOperation
import com.regnosys.rosetta.rosetta.expression.ToDateTimeOperation
import com.regnosys.rosetta.rosetta.expression.ToIntOperation
import com.regnosys.rosetta.rosetta.expression.ToTimeOperation
import com.regnosys.rosetta.rosetta.expression.ToZonedDateTimeOperation
import com.regnosys.rosetta.rosetta.expression.ToEnumOperation
import com.regnosys.rosetta.rosetta.expression.RosettaDeepFeatureCall
import com.regnosys.rosetta.rosetta.expression.MinOperation
import com.regnosys.rosetta.rosetta.expression.MaxOperation
import com.regnosys.rosetta.rosetta.expression.SwitchOperation
import com.regnosys.rosetta.rosetta.expression.SwitchCaseGuard
import com.regnosys.rosetta.rosetta.simple.Attribute
import com.regnosys.rosetta.rosetta.simple.Condition
import com.regnosys.rosetta.rosetta.simple.Data
import com.regnosys.rosetta.rosetta.simple.ShortcutDeclaration
import com.regnosys.rosetta.rosetta.simple.impl.FunctionImpl
import org.eclipse.xtend2.lib.StringConcatenation
import java.util.ArrayList
import java.util.List

// TODO: update missing operators
// TODO: evaluate use of ExpressionSwitch

class PythonExpressionGenerator {

    public var List<String> importsFound
    public var ifCondBlocks = new ArrayList<String>()
    public var isSwitchCond = false

    def String generateExpression(RosettaExpression expr, int ifLevel, boolean isLambda) {
        switch (expr) {
            // literals
            RosettaBooleanLiteral: expr.value.toString().equals("true") ? "True" : "False"
            RosettaIntLiteral: '''«expr.value»'''
            RosettaNumberLiteral: '''«expr.value»'''
            RosettaStringLiteral: '''"«expr.value»"'''
            // xText operations
            AsKeyOperation: '''{«generateExpression(expr.argument, ifLevel, isLambda)»: True}'''
            DistinctOperation: '''set(«generateExpression(expr.argument, ifLevel, isLambda)»)'''
            FilterOperation: generateFilterOperation(expr, ifLevel, isLambda)
            FirstOperation: '''«generateExpression(expr.argument, ifLevel, isLambda)»[0]'''
            FlattenOperation: '''rune_flatten_list(«generateExpression(expr.argument, ifLevel, isLambda)»)'''
            ListLiteral: '''[«FOR arg : expr.elements SEPARATOR ', '»«generateExpression(arg, ifLevel,isLambda)»«ENDFOR»]'''
            LastOperation: '''«generateExpression(expr.argument, ifLevel, isLambda)»[-1]'''
            MapOperation: generateMapOperation(expr, ifLevel, isLambda)
            MaxOperation: '''max(«generateExpression(expr.getArgument(), ifLevel, isLambda)»)'''
            MinOperation: '''min(«generateExpression(expr.getArgument(), ifLevel, isLambda)»)'''
            SortOperation: '''sorted(«generateExpression(expr.argument, ifLevel, isLambda)»)'''
            ThenOperation: generateThenOperation(expr, ifLevel, isLambda)
            SumOperation: '''sum(«generateExpression(expr.argument, ifLevel, isLambda)»)'''
            SwitchOperation: generateSwitchOperation(expr, ifLevel, isLambda)
            ToEnumOperation: '''«expr.enumeration.name»(«generateExpression(expr.argument, ifLevel, isLambda)»)'''
            ToStringOperation: '''rune_str(«generateExpression(expr.argument, ifLevel, isLambda)»)'''
            ToDateOperation: '''datetime.datetime.strptime(«generateExpression(expr.argument, ifLevel, isLambda)», "%Y-%m-%d").date()'''
            ToDateTimeOperation: '''datetime.datetime.strptime(«generateExpression(expr.argument, ifLevel, isLambda)», "%Y-%m-%d %H:%M:%S")'''
            ToIntOperation: '''int(«generateExpression(expr.argument, ifLevel, isLambda)»)'''
            ToTimeOperation: '''datetime.datetime.strptime(«generateExpression(expr.argument, ifLevel, isLambda)», "%H:%M:%S").time()'''
            ToZonedDateTimeOperation:'''datetime.datetime.strptime(«generateExpression(expr.argument, ifLevel, isLambda)», "%Y-%m-%d %H:%M:%S %z %Z")'''
            // Rune Operations
            RosettaAbsentExpression: '''(not rune_attr_exists(«generateExpression(expr.argument, ifLevel, isLambda)»))'''
            RosettaBinaryOperation: generateBinaryExpression(expr, ifLevel, isLambda)
            RosettaConditionalExpression: generateConditionalExpression(expr, ifLevel, isLambda)
            RosettaConstructorExpression: generateConstructorExpression(expr, ifLevel, isLambda)
            RosettaCountOperation: '''rune_count(«generateExpression(expr.argument, ifLevel,isLambda)»)'''
            RosettaDeepFeatureCall: '''rune_resolve_deep_attr(self, "«expr.feature.name»")'''
            RosettaEnumValueReference: '''«expr.enumeration».«EnumHelper.convertValue(expr.value)»'''
            RosettaExistsExpression: '''rune_attr_exists(«generateExpression(expr.argument, ifLevel, isLambda)»)'''
            RosettaFeatureCall: generateFeatureCall(expr, ifLevel, isLambda)
            RosettaOnlyElement: '''rune_get_only_element(«generateExpression(expr.argument, ifLevel, isLambda)»)'''
            RosettaOnlyExistsExpression: '''rune_check_one_of(self, «generateExpression(expr.getArgs().get(0), ifLevel, isLambda)»)'''
            RosettaReference: generateReference(expr, ifLevel, isLambda)
            default:{
                throw new UnsupportedOperationException("Unsupported expression type of " + expr?.class?.simpleName)
            }
        }
    }

    private def String generateConditionalExpression(RosettaConditionalExpression expr, int ifLevel, boolean isLambda) {
        val ifExpr = generateExpression(expr.getIf(), ifLevel + 1, isLambda)
        val ifThen = generateExpression(expr.ifthen, ifLevel + 1, isLambda)
        val elseThen = (expr.elsethen !== null && expr.full) ? generateExpression(expr.elsethen, ifLevel + 1, isLambda) : 'True'
        val ifBlocks = '''
            def _then_fn«ifLevel»():
                return «ifThen»
            
            def _else_fn«ifLevel»():
                return «elseThen»
            
        '''
        ifCondBlocks.add(ifBlocks)
        '''if_cond_fn(«ifExpr», _then_fn«ifLevel», _else_fn«ifLevel»)'''
    }

    private def String generateFeatureCall(RosettaFeatureCall expr, int ifLevel, boolean isLambda) {
        if (expr.feature instanceof RosettaEnumValue) {
            val symbol = (expr.receiver as RosettaSymbolReference).symbol
            val model = symbol.eContainer as RosettaModel
            addImportsFromConditions(symbol.name, model.name)
            return generateEnumString(expr.feature as RosettaEnumValue)
        }
        var right = expr.feature.name
        if (right == "None") 
            right = "NONE"
        var receiver = generateExpression(expr.receiver, ifLevel, isLambda)
        return (receiver === null) ? '''«right»''' : '''rune_resolve_attr(«receiver», "«right»")'''
    }

    private def String generateThenOperation(ThenOperation expr, int ifLevel, boolean isLambda) {
        val funcExpr = expr.function
        val argExpr = generateExpression(expr.argument, ifLevel, isLambda)
        val body = generateExpression(funcExpr.body, ifLevel, true)
        val funcParams = funcExpr.parameters.map[it.name].join(", ")
        val lambdaFunction = (funcParams.empty) ? '''(lambda item: «body»)''' : '''(lambda «funcParams»: «body»)'''
        return '''«lambdaFunction»(«argExpr»)'''
    }

    private def String generateFilterOperation(FilterOperation expr, int ifLevel, boolean isLambda) {
        val argument = generateExpression(expr.argument, ifLevel, isLambda)
        val filterExpression = generateExpression(expr.function.body, ifLevel, true)
        return '''rune_filter(«argument», lambda item: «filterExpression»)'''
    }

    private def String generateMapOperation(MapOperation expr, int ifLevel, boolean isLambda) {
        val inlineFunc = expr.function
        val funcBody = generateExpression(inlineFunc.body, ifLevel, true)
        val lambdaFunction = "lambda item: " + funcBody
        val argument = generateExpression(expr.argument, ifLevel, isLambda)
        return '''list(map(«lambdaFunction», «argument»))'''
    }

    private def String generateConstructorExpression(RosettaConstructorExpression expr, int ifLevel, boolean isLambda) {
        val type = expr.typeCall?.type?.name
        val keyValuePairs = expr.values
        if (type !== null) {
            '''«type»(«FOR pair : keyValuePairs SEPARATOR ', '»«pair.key.name»=«generateExpression(pair.value, ifLevel, isLambda)»«ENDFOR»)'''
        } else {
            '''{«FOR pair : keyValuePairs SEPARATOR ', '»'«pair.key.name»': «generateExpression(pair.value, ifLevel, isLambda)»«ENDFOR»}'''
        }
    }

    private def getGuardExpression(SwitchCaseGuard caseGuard, boolean isLambda){
        if (caseGuard === null) {
            throw new UnsupportedOperationException("Null SwitchCaseGuard")
        }
        val literalGuard = caseGuard.getLiteralGuard();
        if (literalGuard !== null) {
            return '''switchAttribute == «generateExpression(literalGuard, 0, isLambda)»'''
        }
        val enumGuard = caseGuard.getEnumGuard
        if (enumGuard !== null){
            return '''switchAttribute == rune_resolve_attr(«generateEnumString(enumGuard)»,"«enumGuard.getName()»")'''
        }
        val optionGuard = caseGuard.getChoiceOptionGuard
        if (optionGuard !== null){
            return '''rune_resolve_attr(switchAttribute,"«optionGuard.getName()»")'''
        }
        val dataGuard = caseGuard.getDataGuard
        if (dataGuard !== null){
            return '''rune_resolve_attr(switchAttribute,"«dataGuard.getName()»")'''
        }
        throw new UnsupportedOperationException("Unsupported SwitchCaseGuard type")
    }

    private def String generateSwitchOperation(SwitchOperation expr, int ifLevel, boolean isLambda) {
        // translate switch into a series of if / elif statements
        val attr = generateExpression(expr.argument, 0, isLambda)
        
        var _thenFuncsBuilder = new StringConcatenation()
        var _switchLogicBuilder= new StringConcatenation()
        
        val indent = "    "
        isSwitchCond=true
        
        for (pair : expr.cases.indexed) {
            val currentCase = pair.value
            val funcName = (currentCase.isDefault()) ? "_then_default" : "_then_"+ (pair.key+1)
            val thenExprDef = (currentCase.isDefault()) ? generateExpression(expr.getDefault(), 0, isLambda) : generateExpression(currentCase.getExpression(), ifLevel + 1, isLambda)
            
            _thenFuncsBuilder.append(indent)
            _thenFuncsBuilder.append("def "+funcName + "():")
            _thenFuncsBuilder.newLine
            _thenFuncsBuilder.append(indent)
            _thenFuncsBuilder.append("    return "+ thenExprDef)
            _thenFuncsBuilder.newLine
            
            if (currentCase.isDefault()) {
                 // Default else
                _switchLogicBuilder.append(indent)
                _switchLogicBuilder.append("else:")
                _switchLogicBuilder.newLine()
                _switchLogicBuilder.append(indent)
                _switchLogicBuilder.append("    return ")
                _switchLogicBuilder.append(funcName)
                _switchLogicBuilder.append("()")
            } else {
                val guard = currentCase.getGuard()
                val prefix = (pair.key == 0) ? "if " : "elif "
                _switchLogicBuilder.append(indent)
                _switchLogicBuilder.append(prefix)
                _switchLogicBuilder.append(getGuardExpression(guard, isLambda))
                _switchLogicBuilder.append(":")
                _switchLogicBuilder.newLine()
                _switchLogicBuilder.append(indent)
                _switchLogicBuilder.append("    return ")
                _switchLogicBuilder.append(funcName)
                _switchLogicBuilder.append("()")
                _switchLogicBuilder.newLine()
            }
        }

        val _builder= new StringConcatenation
        _builder.append(_thenFuncsBuilder.toString)
        _builder.append(indent)
        _builder.append("switchAttribute = ")
        _builder.append(attr)
        _builder.newLine
        _builder.append(_switchLogicBuilder.toString)

        return _builder.toString
    }
             

    private def String generateReference(RosettaReference expr, int ifLevel, boolean isLambda) {
        switch (expr) {
            RosettaImplicitVariable: '''«expr.name»'''
            RosettaSymbolReference:  generateSymbolReference(expr, ifLevel, isLambda)
        }
    }

    private def String generateSymbolReference(RosettaSymbolReference expr, int ifLevel, boolean isLambda) {
        val symbol = expr.symbol
        switch (symbol) {
            Data, RosettaEnumeration: '''«symbol.name»'''
            Attribute: generateAttributeReference(symbol, isLambda)
            RosettaEnumValue: generateEnumString(symbol)
            RosettaCallableWithArgs: generateCallableWithArgsCall(symbol, expr, ifLevel, isLambda)
            ShortcutDeclaration, ClosureParameter: '''rune_resolve_attr(self, "«symbol.name»")'''
            default: throw new UnsupportedOperationException("Unsupported symbol reference for: " + symbol.class.simpleName)
        }
    }

    private def String generateAttributeReference(Attribute s, boolean isLambda) {
        if (isLambda) {
            var notInput = true
            if (s.eContainer instanceof FunctionImpl) {
                var FunctionImpl c = s.eContainer as FunctionImpl
                for (inputAttr : c.inputs) {
                    if (inputAttr.name.equals(s.name)) {
                        notInput = false
                    }
                }
            }
            return (notInput) ? '''rune_resolve_attr(item, "«s.name»")''' : '''rune_resolve_attr(self, "«s.name»")'''
        } else {
            return '''rune_resolve_attr(self, "«s.name»")'''
        }
    }

    private def String generateEnumString (RosettaEnumValue rev) {
        // translate the enum value to a fully qualified name as long as the value is not None
        
        val value = EnumHelper.convertValue(rev)
        val parent = rev.getEnumeration()
        val parentName = parent.getName()
        val modelName = parent.getModel().getName()
        return '''«modelName».«parentName».«parentName».«value»'''
    } 

    private def String generateCallableWithArgsCall(RosettaCallableWithArgs s, RosettaSymbolReference expr, int ifLevel, boolean isLambda) {
        if (s instanceof FunctionImpl)
            addImportsFromConditions(s.getName(), (s.eContainer as RosettaModel).name + "." + "functions")
        else
            addImportsFromConditions(s.name, (s.eContainer as RosettaModel).name)
        var args = '''«FOR arg : expr.args SEPARATOR ', '»«generateExpression(arg, ifLevel, isLambda)»«ENDFOR»'''
        '''«s.name»(«args»)'''
    }

    private def String generateBinaryExpression(RosettaBinaryOperation expr, int ifLevel, boolean isLambda) {
        if (expr instanceof ModifiableBinaryOperation) {
            if (expr.cardMod === null) {
                throw new UnsupportedOperationException("ModifiableBinaryOperation with expressions with no cardinality")
            }
            if (expr.operator == "<>") {
                '''rune_any_elements(«generateExpression(expr.left, ifLevel,isLambda)», "«expr.operator»", «generateExpression(expr.right, ifLevel, isLambda)»)'''
            } else {
                '''rune_all_elements(«generateExpression(expr.left, ifLevel, isLambda)», "«expr.operator»", «generateExpression(expr.right, ifLevel, isLambda)»)'''
            } 
        } else {
            switch expr.operator {
                case ("="): '''(«generateExpression(expr.left, ifLevel, isLambda)» == «generateExpression(expr.right, ifLevel, isLambda)»)'''
                case ("<>"): '''(«generateExpression(expr.left, ifLevel, isLambda)» != «generateExpression(expr.right, ifLevel, isLambda)»)'''
                case ("contains"): '''rune_contains(«generateExpression(expr.left, ifLevel, isLambda)», «generateExpression(expr.right, ifLevel, isLambda)»)'''
                case ("disjoint"): '''rune_disjoint(«generateExpression(expr.left, ifLevel,isLambda)», «generateExpression(expr.right, ifLevel,isLambda)»)'''
                case ("join"): '''«generateExpression(expr.left, ifLevel, isLambda)».join(«generateExpression(expr.right, ifLevel, isLambda)»)'''
                default: '''(«generateExpression(expr.left, ifLevel, isLambda)» «expr.operator» «generateExpression(expr.right, ifLevel, isLambda)»)'''
            }
        }
    }

    def String generateTypeOrFunctionConditions(Data cls) {
        var nConditions = 0;
        var result = '';
        for (Condition cond : cls.conditions) {
            result += generateConditionBoilerPlate(cond, nConditions)
            if (cond.isConstraintCondition)
                result += generateConstraintCondition(cls, cond)
            else
                result += generateIfThenElseOrSwitch(cond)
            nConditions++
        }
        return result
    }

    def generateFunctionConditions(List<Condition> conditions, String condition_type) {
        var nConditions = 0;
        var result = '';
        for (Condition cond : conditions) {
            result += generateFunctionConditionBoilerPlate(cond, nConditions, condition_type)
            result += generateIfThenElseOrSwitch(cond)
            nConditions++
        }

        return result
    }

    def generateThenElseForFunction(RosettaExpression expr, List<Integer> ifLevel) {
        ifCondBlocks.clear()
        generateExpression(expr, ifLevel.get(0), false)
        var blocks = ""
        if (!ifCondBlocks.isEmpty()) {
            ifLevel.set(0, ifLevel.get(0) + 1)
            blocks = '''    «FOR arg : ifCondBlocks»«arg»«ENDFOR»'''
        }
        return '''«blocks»'''
    }

    private def boolean isConstraintCondition(Condition cond) {
        return isOneOf(cond) || isChoice(cond)
    }

    private def boolean isOneOf(Condition cond) {
        return cond.expression instanceof OneOfOperation
    }

    private def boolean isChoice(Condition cond) {
        return cond.expression instanceof ChoiceOperation
    }

    private def generateConditionBoilerPlate(Condition cond, int nConditions) {
        '''
            
            @rune_condition
            def condition_«nConditions»_«cond.name»(self):
                «IF cond.definition!==null»
                    """
                    «cond.definition»
                    """
                «ENDIF»
                item = self
        '''
    }

    private def generateFunctionConditionBoilerPlate(Condition cond, int nConditions, String condition_type) {
        '''
            
            @rune_local_condition(«condition_type»)
            def condition_«nConditions»_«cond.name»(self):
                «IF cond.definition!==null»
                    """
                    «cond.definition»
                    """
                «ENDIF»
        '''
    }

    private def generateConstraintCondition(Data cls, Condition cond) {
        val expression = cond.expression
        var attributes = cls.attributes
        var necessity = "necessity=True"
        if (expression instanceof ChoiceOperation) {
            attributes = expression.attributes
            if (expression.necessity == Necessity.OPTIONAL) {
                necessity = "necessity=False"
            }
        }
        '''    return rune_check_one_of(self, «FOR a : attributes SEPARATOR ", "»'«a.name»'«ENDFOR», «necessity»)
        '''
    }

    private def generateIfThenElseOrSwitch(Condition c) {
        ifCondBlocks.clear()
        isSwitchCond=false
        
        var expr = generateExpression(c.expression, 0, false)
        if (isSwitchCond) return expr
        var blocks = (ifCondBlocks.isEmpty()) ? "" : '''    «FOR arg : ifCondBlocks»«arg»«ENDFOR»'''
        return '''«blocks»    return «expr»
        '''
    }

    def addImportsFromConditions(String variable, String namespace) {
        val import = '''from «namespace».«variable» import «variable»'''
        if (importsFound !== null && !importsFound.contains(import)) {
            importsFound.add(import)
        }
    }
}
